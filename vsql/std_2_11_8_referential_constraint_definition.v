module vsql

// ISO/IEC 9075-2:2016(E), 11.8, <referential constraint definition>
//
// Specify a referential constraint.

// A FOREIGN KEY, or a REFERENCES on a column. The referenced_columns are empty
// when they aren't given, which means the PRIMARY KEY of the referenced table
// (Syntax Rule 4b). There is no MATCH or referential action, so it's always
// MATCH SIMPLE (Syntax Rule 1) with ON UPDATE NO ACTION and ON DELETE NO ACTION
// (Syntax Rules 12 and 13).
struct ReferentialConstraintDefinition {
	columns            []Identifier
	referenced_table   Identifier
	referenced_columns []Identifier
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
// they correspond to.
struct ForeignKey {
	columns            []string
	referenced_table   Identifier
	referenced_columns []string
}

// str is how the constraint is stored in the file as part of the CREATE TABLE
// (see Table.bytes).
fn (k ForeignKey) str() string {
	return 'FOREIGN KEY (${k.columns.map(delimit_identifier(it)).join(', ')}) REFERENCES ${k.referenced_table.storage_sql()} (${k.referenced_columns.map(delimit_identifier(it)).join(', ')})'
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
			if key_type(typ.typ) != key_type(referencing_typ.typ) {
				return sqlstate_42804('in FOREIGN KEY', typ.str(), referencing_typ.str())
			}
		}

		mut sorted := referenced_columns.clone()
		sorted.sort()
		mut found := false
		mut all_unique_columns := [referenced.primary_key]
		all_unique_columns << referenced.unique_constraints
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
// other type. A referencing column must be comparable with its referenced
// column (Syntax Rule 11). Values that are only comparable after they're cast
// (such as an INTEGER and a NUMERIC) can't be referenced yet.
fn key_type(typ SQLType) SQLType {
	return match typ {
		.is_smallint, .is_integer, .is_bigint { .is_bigint }
		.is_real, .is_double_precision { .is_double_precision }
		.is_numeric, .is_decimal { .is_numeric }
		.is_character, .is_varchar { .is_varchar }
		else { typ }
	}
}

// check_foreign_keys returns an error if a row in rows doesn't reference a row
// of the referenced table of each FOREIGN KEY of t, or might not once another
// transaction finishes. A row that has a NULL in any of the columns of the
// FOREIGN KEY doesn't need to reference a row (MATCH SIMPLE). Like
// check_unique_constraints, the rows must have already been written, so a row
// can reference a row of the same table that's written by the same statement.
//
// Every row of the referenced table is read, there is no index.
fn (mut f Storage) check_foreign_keys(t Table, rows []Row) ! {
	if t.foreign_keys.len == 0 || rows.len == 0 {
		return
	}

	f.isolation_start()!
	defer {
		f.end_isolation()
	}

	for key in t.foreign_keys {
		referenced := f.table(key.referenced_table.storage_id())
		types := key_types(referenced, key.referenced_columns)!

		mut missing := map[string]bool{}
		for row in rows {
			value := key_value(row, key.columns, types)
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
			value := key_value(row, key.referenced_columns, types).bytestr()
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
// A FOREIGN KEY is always ON DELETE NO ACTION and ON UPDATE NO ACTION, so it's
// checked once the whole statement has finished (ISO/IEC 9075-2:2016(E), 15.17
// and 4.23.2).
//
// The referenced columns are a unique constraint (which has already been
// checked), so another row of t can't have the same key. Every row of each
// referencing table is read, there is no index.
fn (mut f Storage) check_referencing_rows(t Table, old_rows []Row, new_rows []Row) ! {
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

			types := key_types(t, key.referenced_columns)!
			mut removed := map[string]bool{}
			for row in old_rows {
				value := key_value(row, key.referenced_columns, types)
				if value.len > 0 {
					removed[value.bytestr()] = true
				}
			}
			for row in new_rows {
				removed.delete(key_value(row, key.referenced_columns, types).bytestr())
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
				if key_value(row, key.columns, types).bytestr() !in removed {
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

// key_types are the types of the columns of t, which are used for the key of
// a row (see key_value).
fn key_types(t Table, columns []string) ![]SQLType {
	mut types := []SQLType{}
	for column in columns {
		types << t.column(column)!.typ.typ
	}

	return types
}
