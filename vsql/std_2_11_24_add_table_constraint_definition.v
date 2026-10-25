module vsql

// ISO/IEC 9075-2:2016(E), 11.24, <add table constraint definition>
//
// Add a constraint to a table.

struct AddTableConstraintDefinition {
	constraint TableElement
}

// execute adds the constraint after the other constraints of the same kind. The
// table is defined again with the constraint, so it's checked the same way as a
// CREATE TABLE, such as for a second PRIMARY KEY, a name that's already used,
// or a FOREIGN KEY that doesn't reference a unique constraint. Every row must
// satisfy the new constraint. The columns of a new PRIMARY KEY become NOT NULL
// (General Rule 2).
fn (d AddTableConstraintDefinition) execute(mut conn Connection, mut catalog CatalogConnection, table Table) ! {
	mut elements := table.elements()
	elements << d.constraint

	definition := TableDefinition{table.name, elements}
	mut new_table := Table{
		...definition.table(table.name, table.tid)!
		id: table.id
	}
	new_table.name_constraints(catalog.storage.schema_constraint_names(table.name))!
	resolve_foreign_keys(mut conn, mut new_table)!

	replace_table_definition(mut conn, mut catalog, table, new_table)!
}

// replace_table_definition replaces the definition of a table with a new
// definition that has different constraints (or fewer columns), and returns
// an error if a row doesn't satisfy one of them (in the same way as an INSERT,
// but for every row of the table). The rows are moved when the PRIMARY KEY
// changes, because they're stored by their PRIMARY KEY (or a row ID when there
// isn't one, see Row.object_key). They're written again when a column's NOT
// NULL changes, because only a nullable column stores whether it's NULL, or
// when a column is dropped (see Row.bytes).
fn replace_table_definition(mut conn Connection, mut catalog CatalogConnection, table Table, new_table Table) ! {
	check_constraints := new_check_constraints(mut conn, new_table)!
	is_moved := new_table.primary_key != table.primary_key
	is_rewritten := new_table.columns.map(it.not_null) != table.columns.map(it.not_null)
		|| new_table.columns.len != table.columns.len

	mut rows := []Row{}
	mut moved := []Row{}
	for row in catalog.storage.read_rows(table.name)! {
		mut r := row.for_storage()
		for column in new_table.columns {
			if column.not_null && r.data[column.name.sub_entity_name].is_null {
				return sqlstate_23502('column ${column.name.sub_entity_name}')
			}
		}
		check_constraints.verify(mut conn, r)!

		if is_moved {
			catalog.storage.delete_row(table.name.storage_id(), mut r)!
			moved << Row{
				...r
				id: []u8{}
			}
		} else {
			rows << r
		}
	}

	catalog.storage.update_table(new_table)!

	if is_rewritten {
		for mut row in rows {
			catalog.storage.update_row(mut row, new_table)!
		}
	}
	for mut row in moved {
		catalog.storage.write_row(mut row, new_table)!
	}
	rows << moved
	catalog.storage.check_unique_constraints(new_table, rows)!
	catalog.storage.check_foreign_keys(new_table, rows)!
}
