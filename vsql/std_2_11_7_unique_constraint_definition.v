module vsql

// ISO/IEC 9075-2:2016(E), 11.7, <unique constraint definition>
//
// Specify a uniqueness constraint for a table.

// The name is empty when the constraint doesn't have a <constraint name
// definition> (see Table.name_constraints).
struct UniqueConstraintDefinition {
	name           Identifier
	columns        []Identifier
	is_primary_key bool
}

// A UniqueConstraint is a UNIQUE (other than the PRIMARY KEY) of a table, with
// the names of its columns.
struct UniqueConstraint {
	name    string
	columns []string
}

// str is how the constraint is stored in the file as part of the CREATE TABLE
// (see Table.bytes).
fn (c UniqueConstraint) str() string {
	return 'UNIQUE (${c.columns.map(delimit_identifier(it)).join(', ')})'
}

// check_primary_key returns an error if a row with the same PRIMARY KEY as r
// already exists in t, or might exist once another transaction finishes. It
// must be called from inside an isolation block.
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
			return sqlstate_23505('PRIMARY KEY on ${t.name}')
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
// are checked once all of the rows of a statement have been written (ISO/IEC
// 9075-2:2016(E), 4.23.2), so that UPDATE t SET u = u + 1 works.
//
// Every row of t is read, there is no index.
fn (mut f Storage) check_unique_constraints(t Table, rows []Row) ! {
	if t.unique_constraints.len == 0 || rows.len == 0 {
		return
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// For each constraint, the object key of the row that has each unique key.
	mut new_keys := []map[string][]u8{len: t.unique_constraints.len}
	for row in rows {
		mut r := row
		object_key := r.object_key(t)!
		for i, constraint in t.unique_constraints {
			key := unique_key(row, t, constraint.columns)!
			if key.len > 0 {
				new_keys[i][key.bytestr()] = object_key
			}
		}
	}

	mut iter := f.btree.new_range_iterator(row_key_prefix(t.id), row_key_prefix(t.id + 1))
	for {
		object := iter.next() or { break }
		row := new_row_from_bytes(t, object.value, object.tid).for_storage()
		for i, constraint in t.unique_constraints {
			key := unique_key(row, t, constraint.columns)!
			if key.len == 0 {
				continue
			}

			// A row only conflicts with a different row, and two new rows
			// with the same key are different rows.
			object_key := new_keys[i][key.bytestr()] or { continue }
			if object.key == object_key {
				continue
			}

			if f.is_concurrent_write(object) {
				return sqlstate_40001('avoiding concurrent write on individual row')
			}

			if object.xid == 0 {
				return sqlstate_23505('UNIQUE (${constraint.columns.map(requote_identifier(it)).join(', ')}) on ${t.name}')
			}
		}
	}
	if err := iter.err {
		return err
	}
}

// unique_key is the values of the columns in a row, encoded so that values that
// are equal have the same key (like the PRIMARY KEY, see Row.object_key). It's
// empty if any of the values are NULL.
fn unique_key(row Row, t Table, columns []string) ![]u8 {
	return key_value(row, columns, key_types(t, columns)!)
}

// key_value is the values of the columns in a row, encoded as the types (which
// are in the same order as the columns). It's empty if any of the values are
// NULL.
fn key_value(row Row, columns []string, types []SQLType) []u8 {
	mut key := new_empty_bytes()
	for i, column in columns {
		value := row.data[column]
		if value.is_null {
			return []u8{}
		}
		write_key_value(mut key, key_type_value(value, types[i]), types[i])
	}

	return key.bytes()
}

// key_type_value converts an exact numeric value to the type that it's compared
// as in a key (see foreign_key_type). Any other value is already that type.
fn key_type_value(value Value, typ SQLType) Value {
	match value.typ.typ {
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
fn (mut f Storage) is_concurrent_write(object PageObject) bool {
	return (object.tid != f.transaction_id && f.header.active_transaction_ids.exists(object.tid))
		|| (object.xid != 0 && object.xid != f.transaction_id
			&& f.header.active_transaction_ids.exists(object.xid))
}
