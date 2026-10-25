module vsql

// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>
//
// Specify a referential constraint.

// A FOREIGN KEY, or a REFERENCES on a column. The referenced_columns are empty
// when they aren't given, which means the PRIMARY KEY of the referenced table
// (Syntax Rule 4b). There is no MATCH or ON UPDATE, so it's always MATCH
// SIMPLE (Syntax Rule 1) with ON UPDATE NO ACTION (Syntax Rule 12). The
// delete_rule is empty when there's no ON DELETE.
struct ReferentialConstraintDefinition {
	name               Identifier
	columns            []Identifier
	referenced_table   Identifier
	referenced_columns []Identifier
	delete_rule        string // CASCADE, SET NULL, SET DEFAULT or NO ACTION
}

fn new_referential_constraint_definition(columns []Identifier, references ReferentialConstraintDefinition) ReferentialConstraintDefinition {
	return ReferentialConstraintDefinition{
		...references
		columns: columns
	}
}

// A ForeignKey is a referential constraint of a table. Once the table has been
// created, the referenced_table is fully qualified and the referenced_columns
// are always known (see resolve_foreign_keys), in the order of the columns that
// they correspond to. The delete_rule is empty for ON DELETE NO ACTION.
struct ForeignKey {
	name               string
	columns            []string
	referenced_table   Identifier
	referenced_columns []string
	delete_rule        string // CASCADE, SET NULL or SET DEFAULT
}

// str is how the constraint is stored in the file as part of the CREATE TABLE
// (see Table.bytes).
fn (k ForeignKey) str() string {
	mut s := 'FOREIGN KEY (${k.columns.map(delimit_identifier(it)).join(', ')}) REFERENCES ${k.referenced_table.storage_sql()} (${k.referenced_columns.map(delimit_identifier(it)).join(', ')})'
	if k.delete_rule != '' {
		s += ' ON DELETE ${k.delete_rule}'
	}

	return s
}

// delete_action is the referential action of the ON DELETE.
fn (k ForeignKey) delete_action() string {
	return if k.delete_rule == '' { 'NO ACTION' } else { k.delete_rule }
}

// violation is the error for a row of t (the referencing table) that doesn't
// reference a row of the referenced table.
fn (k ForeignKey) violation(t Table) IError {
	return sqlstate_23503('FOREIGN KEY (${k.columns.map(requote_identifier(it)).join(', ')}) REFERENCES ${k.referenced_table} (${k.referenced_columns.map(requote_identifier(it)).join(', ')}) on ${t.name}')
}

// resolve_foreign_keys finds the table and columns that each FOREIGN KEY of a
// new definition of table references, and checks them. The referenced table
// can be the table itself. It must be in the same catalog, because each
// catalog is a separate file.
fn resolve_foreign_keys(mut conn Connection, mut table Table) ! {
	for i, key in table.foreign_keys {
		mut name := conn.resolve_identifier(key.referenced_table)
		if name.catalog_name != table.name.catalog_name {
			return sqlstate_0a000('FOREIGN KEY cannot reference a table in another catalog: ${name}')
		}

		referenced := if name.storage_id() == table.name.storage_id() {
			table
		} else {
			name = conn.resolve_table_identifier(name, false)!
			conn.catalog_for(name).storage.table(name.storage_id())
		}

		// Syntax Rule 4b.
		mut referenced_columns := key.referenced_columns.clone()
		if referenced_columns.len == 0 {
			if referenced.primary_key.len == 0 {
				return sqlstate_42830('${name} has no PRIMARY KEY')
			}
			referenced_columns = referenced.primary_key.clone()
		}

		// Syntax Rule 11.
		if referenced_columns.len != key.columns.len {
			return sqlstate_42830('FOREIGN KEY has ${key.columns.len} ${pluralize(key.columns.len, 'column')} but REFERENCES ${name} has ${referenced_columns.len}')
		}

		// The referenced columns must be the columns of a unique constraint
		// (Syntax Rule 4a), in any order.
		for j, column in referenced_columns {
			typ := referenced.column(column)!.typ
			referencing_typ := table.column(key.columns[j])!.typ
			if !is_comparable_key_type(typ.typ, referencing_typ.typ) {
				return sqlstate_42804('in FOREIGN KEY', typ.str(), referencing_typ.str())
			}
		}

		mut sorted := referenced_columns.clone()
		sorted.sort()
		mut found := false
		mut all_unique_columns := [referenced.primary_key]
		all_unique_columns << referenced.unique_constraints.map(it.columns)
		for unique_columns in all_unique_columns {
			mut sorted_unique := unique_columns.clone()
			sorted_unique.sort()
			if sorted_unique.len > 0 && sorted_unique == sorted {
				found = true
			}
		}

		if !found {
			return sqlstate_42830('there is no PRIMARY KEY or UNIQUE (${referenced_columns.map(requote_identifier(it)).join(', ')}) on ${name}')
		}

		table.foreign_keys[i] = ForeignKey{
			...key
			referenced_table:   name
			referenced_columns: referenced_columns
		}
	}
}

// key_type is the same for types that can be compared as keys, because a value
// of one type has the same key (see write_key_value) as the same value of the
// other type.
fn key_type(typ SQLType) SQLType {
	return match typ {
		.is_smallint, .is_integer, .is_bigint { .is_bigint }
		.is_real, .is_double_precision { .is_double_precision }
		.is_numeric, .is_decimal { .is_numeric }
		.is_character, .is_varchar { .is_varchar }
		else { typ }
	}
}

// is_comparable_key_type is true if a referencing column of type a can reference
// a column of type b. They must be comparable (Syntax Rule 11), so any two
// numeric types, and datetimes with the same datetime fields (with or without a
// time zone), can be used (Feature T201).
fn is_comparable_key_type(a SQLType, b SQLType) bool {
	return key_type(a) == key_type(b) || (a.is_number() && b.is_number())
		|| (a.is_datetime() && b.is_datetime() && datetime_fields(a) == datetime_fields(b))
}

// foreign_key_type is the type that the values of a referencing column of type
// a and its referenced column of type b are compared as. An exact numeric is
// compared with an approximate numeric as a DOUBLE PRECISION, and a datetime
// without a time zone is compared with one with a time zone in UTC, like any
// other comparison (ISO/IEC 9075-2:2016(E), 8.2 <comparison predicate>, General
// Rules 2 and 6).
fn foreign_key_type(a SQLType, b SQLType) SQLType {
	ka, kb := key_type(a), key_type(b)
	if ka == kb {
		return ka
	}

	if a.is_datetime() {
		return if datetime_fields(a) == 'TIME' {
			SQLType.is_time_with_time_zone
		} else {
			SQLType.is_timestamp_with_time_zone
		}
	}

	if ka == .is_double_precision || kb == .is_double_precision {
		return .is_double_precision
	}

	return .is_numeric
}

// check_foreign_keys returns an error if a row in rows doesn't reference a row
// of the referenced table of each FOREIGN KEY of t, or might not once another
// transaction finishes. A row that has a NULL in any of the columns of the
// FOREIGN KEY doesn't need to reference a row (MATCH SIMPLE). Like
// check_unique_constraints, the rows must have already been written, so a row
// can reference a row of the same table that's written by the same statement.
//
// A datetime without a time zone is in the session time zone (time_zone, in
// minutes) when it's compared with one with a time zone.
//
// Every row of the referenced table is read, there is no index.
fn (mut f Storage) check_foreign_keys(t Table, rows []Row, time_zone i16) ! {
	if t.foreign_keys.len == 0 || rows.len == 0 {
		return
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	for key in t.foreign_keys {
		referenced := f.table(key.referenced_table.storage_id())
		types := foreign_key_types(t, key.columns, referenced, key.referenced_columns)!

		mut missing := map[string]bool{}
		for row in rows {
			value := key_value(row, key.columns, types, time_zone)
			if value.len > 0 {
				missing[value.bytestr()] = true
			}
		}
		if missing.len == 0 {
			continue
		}

		// A row that another transaction is writing only matters if there
		// isn't another row with the same key, so the result doesn't depend on
		// the order of the rows.
		mut concurrent := map[string]bool{}
		mut iter := f.btree.new_range_iterator(row_key_prefix(referenced.id), row_key_prefix(referenced.id + 1))
		for {
			object := iter.next() or { break }
			row := new_row_from_bytes(referenced, object.value, object.tid).for_storage()
			value := key_value(row, key.referenced_columns, types, time_zone).bytestr()
			if value !in missing {
				continue
			}

			if f.is_concurrent_write(object) {
				concurrent[value] = true
			} else if object.xid == 0 {
				missing.delete(value)
			}
		}
		if err := iter.err {
			return err
		}

		for value, _ in missing {
			if value in concurrent {
				return sqlstate_40001('avoiding concurrent write on individual row')
			}
		}

		if missing.len > 0 {
			return key.violation(t)
		}
	}
}

// check_referencing_rows returns an error if a row of a table that references
// t (including t itself) references a key that's in old_rows but not new_rows,
// or might once another transaction finishes. The old_rows are the rows of t
// that a statement deleted or updated, and new_rows are the rows that it wrote.
// The referential delete actions (see apply_delete_rules) have already been
// carried out, and a FOREIGN KEY is always ON UPDATE NO ACTION, so it's checked
// once the whole statement has finished (ISO/IEC 9075-2:2016(E), 15.17 and
// 4.23.2).
//
// The referenced columns are a unique constraint (which has already been
// checked), so another row of t can't have the same key. time_zone is the same
// as for check_foreign_keys. Every row of each referencing table is read, there
// is no index.
fn (mut f Storage) check_referencing_rows(t Table, old_rows []Row, new_rows []Row, time_zone i16) ! {
	if old_rows.len == 0 {
		return
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	// The tables are sorted so that the same error is always returned.
	mut table_names := f.tables.keys()
	table_names.sort()
	for table_name in table_names {
		referencing := f.table(table_name)
		for key in referencing.foreign_keys {
			if key.referenced_table.storage_id() != t.name.storage_id() {
				continue
			}

			types := foreign_key_types(referencing, key.columns, t, key.referenced_columns)!
			mut removed := map[string]bool{}
			for row in old_rows {
				value := key_value(row, key.referenced_columns, types, time_zone)
				if value.len > 0 {
					removed[value.bytestr()] = true
				}
			}
			for row in new_rows {
				removed.delete(key_value(row, key.referenced_columns, types, time_zone).bytestr())
			}
			if removed.len == 0 {
				continue
			}

			// A row that references a removed key is an error, even if another
			// transaction is also writing a row that references it.
			mut is_concurrent := false
			mut iter := f.btree.new_range_iterator(row_key_prefix(referencing.id), row_key_prefix(referencing.id + 1))
			for {
				object := iter.next() or { break }
				row := new_row_from_bytes(referencing, object.value, object.tid).for_storage()
				if key_value(row, key.columns, types, time_zone).bytestr() !in removed {
					continue
				}

				if f.is_concurrent_write(object) {
					is_concurrent = true
				} else if object.xid == 0 {
					return key.violation(referencing)
				}
			}
			if err := iter.err {
				return err
			}

			if is_concurrent {
				return sqlstate_40001('avoiding concurrent write on individual row')
			}
		}
	}
}

// apply_delete_rules carries out the referential delete actions of the
// FOREIGN KEYs that reference t (including t itself) for the rows of t that a
// DELETE deleted, and then checks the FOREIGN KEYs that reference each table
// that has deleted rows. A row that's deleted by ON DELETE CASCADE can have its
// own referencing rows, so this repeats until no more rows are deleted. A row
// that's replaced by ON DELETE SET NULL or SET DEFAULT is checked like a row
// that's changed by an UPDATE.
//
// The referencing tables are in the same catalog as t (see
// resolve_foreign_keys), so they're all in f.
//
// ISO/IEC 9075-2:2016(E), 15.17, Execution of referential actions, General
// Rule 9a
fn apply_delete_rules(mut conn Connection, mut f Storage, t Table, rows []Row) ! {
	_, time_zone := conn.now()
	mut deleted := map[string][]Row{}
	mut old := map[string][]Row{}
	mut new := map[string][]Row{}

	// The tables are sorted so that the rows are always changed in the same
	// order.
	mut table_names := f.tables.keys()
	table_names.sort()

	mut pending_tables := [t.name.storage_id()]
	mut pending_rows := [rows]
	for pending_tables.len > 0 {
		table := f.table(pending_tables.pop())
		removed_rows := pending_rows.pop()
		deleted[table.name.storage_id()] << removed_rows

		for table_name in table_names {
			referencing := f.table(table_name)
			for key in referencing.foreign_keys {
				if key.delete_rule == ''
					|| key.referenced_table.storage_id() != table.name.storage_id() {
					continue
				}

				matching := f.matching_rows(key, referencing, table, removed_rows,
					time_zone)!
				if matching.len == 0 {
					continue
				}

				if key.delete_rule == 'CASCADE' {
					for row in matching {
						mut before := row
						f.delete_row(table_name, mut before)!
					}
					pending_tables << table_name
					pending_rows << matching
					continue
				}

				check_constraints := new_check_constraints(mut conn, referencing)!
				for row in matching {
					mut before := row
					mut after := Row{
						id:   row.id
						tid:  row.tid
						data: row.data.clone()
					}
					for column in key.columns {
						value := if key.delete_rule == 'SET NULL' {
							ContextuallyTypedValueSpecification(NullSpecification{})
						} else {
							ContextuallyTypedValueSpecification(DefaultSpecification{})
						}
						after.data[column] = insert_value(mut conn, map[string]Value{},
							referencing.column(column)!, value)!
					}
					check_constraints.verify(mut conn, after)!

					// Like an UPDATE, a row that gets a new PRIMARY KEY is
					// deleted and written again.
					if before.object_key(referencing)! != after.object_key(referencing)! {
						f.delete_row(table_name, mut before)!
						f.write_row(mut after, referencing)!
					} else {
						f.update_row(mut after, referencing)!
					}
					old[table_name] << before
					new[table_name] << after
				}
			}
		}
	}

	for table_name in table_names {
		table := f.table(table_name)
		if table_name in new {
			f.check_unique_constraints(table, new[table_name])!
			f.check_foreign_keys(table, new[table_name], time_zone)!
			f.check_referencing_rows(table, old[table_name], new[table_name], time_zone)!
		}
		if table_name in deleted {
			f.check_referencing_rows(table, deleted[table_name], [], time_zone)!
		}
	}
}

// matching_rows are the rows of the referencing table that reference one of
// the rows of the referenced table by the FOREIGN KEY. The matching rows are
// changed by the referential action, so it's an error if another transaction is
// writing one of them.
//
// ISO/IEC 9075-2:2016(E), 15.17, Execution of referential actions, General
// Rule 6a
fn (mut f Storage) matching_rows(key ForeignKey, referencing Table, referenced Table, rows []Row, time_zone i16) ![]Row {
	types := foreign_key_types(referencing, key.columns, referenced, key.referenced_columns)!
	mut keys := map[string]bool{}
	for row in rows {
		value := key_value(row, key.referenced_columns, types, time_zone)
		if value.len > 0 {
			keys[value.bytestr()] = true
		}
	}
	if keys.len == 0 {
		return []Row{}
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	mut matching := []Row{}
	mut iter := f.btree.new_range_iterator(row_key_prefix(referencing.id), row_key_prefix(referencing.id + 1))
	for {
		object := iter.next() or { break }
		row := new_row_from_bytes(referencing, object.value, object.tid).for_storage()
		if key_value(row, key.columns, types, time_zone).bytestr() !in keys {
			continue
		}

		if f.is_concurrent_write(object) {
			return sqlstate_40001('avoiding concurrent write on individual row')
		}
		if object.xid == 0 {
			matching << row
		}
	}
	if err := iter.err {
		return err
	}

	return matching
}

// referencing_tables are the names of the other tables that reference t.
fn (f Storage) referencing_tables(t Table) []Identifier {
	mut names := []Identifier{}
	for _, table in f.tables {
		if table.name.storage_id() == t.name.storage_id() {
			continue
		}

		for key in table.foreign_keys {
			if key.referenced_table.storage_id() == t.name.storage_id() {
				names << table.name
				break
			}
		}
	}

	return names
}

// drop_foreign_keys_referencing drops the FOREIGN KEYs of the other tables that
// reference any of the tables (by their storage_id), which are being dropped by
// a DROP TABLE or DROP SCHEMA with CASCADE (11.31, General Rule 3).
fn (mut f Storage) drop_foreign_keys_referencing(table_names []string) ! {
	// The tables are sorted so that they're always changed in the same order.
	mut names := f.tables.keys()
	names.sort()
	for name in names {
		if name in table_names {
			continue
		}

		mut table := f.table(name)
		keys := table.foreign_keys.filter(it.referenced_table.storage_id() !in table_names)
		if keys.len != table.foreign_keys.len {
			table.foreign_keys = keys
			f.update_table(table)!
		}
	}
}

// foreign_key_types are the types that the columns of a FOREIGN KEY of
// referencing and the columns of referenced are compared as (see
// foreign_key_type and key_value).
fn foreign_key_types(referencing Table, columns []string, referenced Table, referenced_columns []string) ![]SQLType {
	mut types := []SQLType{}
	for i, column in columns {
		types << foreign_key_type(referencing.column(column)!.typ.typ, referenced.column(referenced_columns[i])!.typ.typ)
	}

	return types
}

// key_types are the types of the columns of t, which are used for the key of
// a row (see key_value).
fn key_types(t Table, columns []string) ![]SQLType {
	mut types := []SQLType{}
	for column in columns {
		types << t.column(column)!.typ.typ
	}

	return types
}
