module vsql

// ISO/IEC 9075-2:2016(E), 11.11, <add column definition>
//
// Add a column to a table.

// The column_definition is the column, followed by the table constraints of
// its column constraints (see add_column_constraint).
struct AddColumnDefinition {
	column_definition []TableElement
}

// execute adds the column after the last column of the table. The table is
// defined again with the new column, so it's checked the same way as a CREATE
// TABLE, such as for a duplicate column name or a second PRIMARY KEY.
//
// Every existing row gets the default of the column (General Rule 3), which is
// only evaluated once. A row that was written before the column was added is
// read with NULL for it (see new_row_from_bytes), so the rows only need to be
// rewritten when the default isn't NULL. The rows must satisfy the constraints
// of the new column, so a NOT NULL column without a default can only be added
// to an empty table, a UNIQUE column with a default to a table with at most
// one row, and a REFERENCES column with a default to a table whose rows can all
// reference that default.
fn (d AddColumnDefinition) execute(mut conn Connection, mut catalog CatalogConnection, table Table, params map[string]Value) ! {
	mut elements := table.elements()
	elements << d.column_definition

	definition := TableDefinition{table.name, elements}
	definition.check_limits(table.name)!
	mut new_table := Table{
		...definition.table(table.name, table.tid)!
		id: table.id
	}
	new_table.name_constraints(catalog.storage.schema_constraint_names(table.name))!
	resolve_foreign_keys(mut conn, mut new_table)!
	column := new_table.columns.last()
	if _ := column.identity {
		return sqlstate_0a000('cannot add identity column ${column.name.sub_entity_name}')
	}
	check_default_clause(mut conn, column)!
	check_constraints := new_check_constraints(mut conn, new_table)!

	// NOT NULL is checked here, so that it's only an error when there are rows.
	value := insert_value(mut conn, params, table, Column{ ...column, not_null: false },
		ContextuallyTypedValueSpecification(DefaultSpecification{}))!

	// A row that gets a new key, because the column is the PRIMARY KEY, is
	// deleted and written again (like an UPDATE).
	mut moved := []Row{}
	mut updated := []Row{}
	if !value.is_null || column.not_null {
		for row in catalog.storage.read_rows(table.name)! {
			if value.is_null {
				return sqlstate_23502('column ${column.name.sub_entity_name}')
			}

			mut before := row.for_storage()
			mut after := row.for_storage()
			after.data[column.name.sub_entity_name] = value
			check_constraints.verify(mut conn, after)!
			if before.object_key(table)! != after.object_key(new_table)! {
				catalog.storage.delete_row(table.name.storage_id(), mut before)!
				moved << after
			} else {
				catalog.storage.update_row(mut after, new_table)!
				updated << after
			}
		}
	}

	catalog.storage.update_table(new_table)!

	for mut row in moved {
		catalog.storage.write_row(mut row, new_table)!
	}
	updated << moved
	catalog.storage.check_unique_constraints(new_table, updated)!
	_, time_zone := conn.now()
	catalog.storage.check_foreign_keys(new_table, updated, time_zone)!
}
