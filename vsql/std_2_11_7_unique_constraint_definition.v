module vsql

// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>
//
// Specify a uniqueness constraint for a table.
//
// The grammar needs at least one column for a UNIQUE, PRIMARY KEY or FOREIGN
// KEY, which is the assertion of ISO/IEC 9075-11:2006, 6.3,
// KEY_DEGREE_GREATER_THAN_OR_EQUAL_TO_1 assertion.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.25.3.2, Unique constraints

// The name is empty when the constraint doesn't have a <constraint name
// definition> (see Table.name_constraints).
struct UniqueConstraintDefinition {
	name            Identifier
	columns         []Identifier
	is_primary_key  bool
	characteristics ConstraintCharacteristics
}

// A UniqueConstraint is a UNIQUE (other than the PRIMARY KEY) of a table, with
// the names of its columns.
struct UniqueConstraint {
	name            string
	columns         []string
	characteristics ConstraintCharacteristics
}

// str is how the constraint is stored in the file as part of the CREATE TABLE
// (see Table.bytes).
fn (c UniqueConstraint) str() string {
	return 'UNIQUE (${c.columns.map(delimit_identifier(it)).join(', ')})${c.characteristics}'
}

// check_primary_key returns an error if a row with the same PRIMARY KEY as r
// already exists in t, or might exist once another transaction finishes. It
// must be called from inside an isolation block. A PRIMARY KEY column can't be
// NULL (see Column.not_null).
//
// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 6.e.i
// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, General Rules, 3
fn (mut f Storage) check_primary_key(mut r Row, t Table) ! {
	if t.primary_key.len == 0 {
		return
	}

	key := r.object_key(t)!
	mut iter := f.btree.new_range_iterator(key, key)
	for {
		object := iter.next() or { break }
		if f.is_concurrent_write(object) {
			return sqlstate_40001('avoiding concurrent write on individual row')
		}

		// Otherwise, the row exists unless it was deleted (by this or a
		// committed transaction).
		if object.xid == 0 {
			return sqlstate_23505('PRIMARY KEY on ${t.name}', t.constraint_identifier(t.primary_key_name),
				t.name)
		}
	}
	if err := iter.err {
		return err
	}
}

// check_unique_constraints returns an error if a row in rows has the same values
// for the columns of a UNIQUE constraint as another row in t, or might once
// another transaction finishes. A row with a NULL in any of the columns never
// conflicts. The rows must have already been written, because the constraints
// are checked once all of the rows of a statement have been written, so that
// UPDATE t SET u = u + 1 works. A deferred constraint isn't checked (see
// defer_check).
//
// Only the entries of the index of the constraint (see constraint_index) that
// have the same values are read.
//
// ISO/IEC 9075-2:2023, 4.25.2, Checking of constraints
// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 6.d.ii
// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, General Rules, 3
fn (mut f Storage) check_unique_constraints(t Table, rows []Row) ! {
	if rows.len == 0 {
		return
	}

	for constraint in t.unique_constraints {
		if f.defer_check(t, constraint.name, constraint.characteristics) {
			continue
		}

		index := f.constraint_index(t, constraint)!
		for row in rows {
			if f.has_duplicate_entry(index, t, row)! {
				return sqlstate_23505('UNIQUE (${constraint.columns.map(requote_identifier(it)).join(', ')}) on ${t.name}',
					t.constraint_identifier(constraint.name), t.name)
			}
		}
	}
}

// key_value is the values of the columns in a row, encoded as the types (which
// are in the same order as the columns). It's empty if any of the values are
// NULL.
fn key_value(row Row, columns []string, types []SQLType, time_zone i16) []u8 {
	mut key := new_empty_bytes()
	for i, column in columns {
		value := row.data.value(column)
		if value.is_null {
			return []u8{}
		}
		write_key_value(mut key, key_type_value(value, types[i], time_zone), types[i])
	}

	return key.bytes()
}

// key_type_value converts an exact numeric value, or a datetime without a time
// zone, to the type that it's compared as in a key (see foreign_key_type). A
// datetime without a time zone is in the session time zone (time_zone, in
// minutes). Any other value is already that type.
fn key_type_value(value Value, typ SQLType, time_zone i16) Value {
	match value.typ.typ {
		.is_time_without_time_zone, .is_timestamp_without_time_zone {
			if typ == .is_time_with_time_zone || typ == .is_timestamp_with_time_zone {
				mut t := value.time_value()
				t.time_zone = time_zone
				return Value{
					typ: value.typ
					v:   InternalValue{
						time_value: box_time(t)
					}
				}
			}
		}
		.is_smallint, .is_integer, .is_bigint {
			if typ == .is_double_precision {
				return new_double_precision_value(f64(value.int_value()))
			}
			if typ == .is_numeric {
				return new_numeric_value(value.int_value().str())
			}
		}
		.is_numeric, .is_decimal {
			if typ == .is_double_precision {
				return new_double_precision_value(value.numeric_value().f64())
			}
		}
		else {}
	}

	return value
}

// is_concurrent_write is true if another transaction is creating or deleting
// the object, so it may or may not exist when that transaction finishes. It
// must be called from inside an isolation block.
//
// For a REPEATABLE READ transaction, it's also true when another transaction
// created or deleted it after the snapshot was taken (first committer wins).
// Otherwise, a change to a row that it can't see (or can still see after it
// was deleted) would be lost, or a constraint would be checked against rows
// that aren't the latest, which isn't allowed at any isolation level
// (ISO/IEC 9075-2:2023, 4.43.4, Isolation levels of SQL-transactions).
fn (mut f Storage) is_concurrent_write(object PageObject) bool {
	if f.snapshot_isolation {
		return (object.tid != f.transaction_id
			&& !f.transaction_snapshot.is_committed(object.tid))
			|| (object.xid != 0 && object.xid != f.transaction_id
				&& !f.transaction_snapshot.is_committed(object.xid))
	}

	return (object.tid != f.transaction_id && f.header.active_transaction_ids.exists(object.tid))
		|| (object.xid != 0 && object.xid != f.transaction_id
			&& f.header.active_transaction_ids.exists(object.xid))
}
