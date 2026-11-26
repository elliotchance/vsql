module vsql

// ISO/IEC 9075-2:2023, 11.24, <add table constraint definition>
//
// Add a constraint to a table.

struct AddTableConstraintDefinition {
	constraint TableElement
}

// execute adds the constraint after the other constraints of the same kind. The
// table is defined again with the constraint, so it's checked the same way as a
// CREATE TABLE, such as for a second PRIMARY KEY, a name that's already used,
// or a FOREIGN KEY that doesn't reference a unique constraint. Every row must
// satisfy the new constraint. The columns of a new PRIMARY KEY become NOT NULL.
//
// ISO/IEC 9075-2:2023, 11.24, <add table constraint definition>, General Rules, 1 and 2
// ISO/IEC 9075-2:2023, 11.7, <unique constraint definition>, Syntax Rules, 10
fn (d AddTableConstraintDefinition) execute(mut conn Connection, mut catalog CatalogConnection, table Table) ! {
	mut elements := table.elements()
	// The copy works around https://github.com/vlang/v/issues/32943 (-autofree).
	elements << own_copy(&d.constraint)

	definition := TableDefinition{
		table_name:     table.name
		table_elements: elements
	}
	mut new_table := Table{
		...definition.table(table.name, table.tid)!
		id: table.id
	}
	new_table.name_constraints(catalog.storage.schema_constraint_names(table.name), catalog.storage.schema_index_names(table.name))!
	resolve_foreign_keys(mut conn, mut new_table)!
	check_new_check_constraints(mut conn, new_table, table.check_constraints.len)!

	replace_table_definition(mut conn, mut catalog, table, new_table)!
}

// replace_table_definition replaces the definition of a table with a new
// definition that has different constraints (or fewer columns), and returns
// an error if a row doesn't satisfy one of them (in the same way as an INSERT,
// but for every row of the table). The rows are moved when the key columns
// change, because they're stored by their PRIMARY KEY (or a row ID when there
// isn't one, or it's DEFERRABLE, see Table.key_columns). They're written again
// when a column's NOT NULL changes, because only a nullable column stores
// whether it's NULL, or when a column is dropped (see Row.bytes).
//
// When the type of a column changes, its values are cast to the new type, and
// the rows are written again because a value is stored by its type. They're
// moved when it's one of the key columns, and an index of the column is
// created again, because its key also depends on the type.
//
// It's manualfree because -autofree frees the tables (and their rows) while
// they're still used, in many ways that don't have a small repro yet.
@[manualfree]
fn replace_table_definition(mut conn Connection, mut catalog CatalogConnection, table Table, new_table Table) ! {
	check_constraints := new_check_constraints(mut conn, new_table)!
	mut changed_types := map[string]Type{}
	for i, column in new_table.columns {
		if i < table.columns.len && column.typ != table.columns[i].typ {
			changed_types[column.name.sub_entity_name] = column.typ
		}
	}
	is_rewritten := new_table.columns.map(it.not_null) != table.columns.map(it.not_null)
		|| new_table.columns.len != table.columns.len || changed_types.len > 0
	indexes := catalog.storage.table_indexes(table.id).filter(it.columns.any(it.name in changed_types))
	for index in indexes {
		catalog.storage.delete_index(index)!
	}
	// A new DEFERRABLE PRIMARY KEY gets an index (see build_constraint_indexes)
	// that's built from the rows that are stored when the definition is
	// replaced, so the rows are moved rather than written again after that.
	is_moved := new_table.key_columns() != table.key_columns()
		|| (is_rewritten && new_table.primary_key != table.primary_key)
		|| new_table.key_columns().any(it in changed_types)

	mut rows := []Row{}
	mut moved := []Row{}
	for row in catalog.storage.read_rows(table.name)! {
		mut r := row.for_storage()

		// A row that's moved is deleted by its key with the old types.
		if is_moved {
			catalog.storage.delete_row(table.name.storage_id(), mut r)!
		}
		for name, typ in changed_types {
			r.data.set(name, cast(mut conn, 'for column ${name}', r.data.value(name), typ)!)
		}
		for column in new_table.columns {
			if column.not_null && r.data.value(column.name.sub_entity_name).is_null {
				return sqlstate_23502(new_table, column.name.sub_entity_name)
			}
		}
		check_constraints.verify(mut conn, r)!

		if is_moved {
			moved << Row{
				...r
				id: []u8{}
			}
		} else {
			rows << r
		}
	}

	// The rows are written before the definition, because it creates the index
	// of a constraint again from the rows when it's missing.
	if is_rewritten {
		for mut row in rows {
			catalog.storage.update_row(row, mut row, new_table)!
		}
	}
	catalog.storage.update_table(new_table)!
	for mut row in moved {
		catalog.storage.write_row(mut row, new_table)!
	}
	rows << moved
	for index in indexes {
		if index.name.storage_id() !in catalog.storage.indexes {
			catalog.storage.create_index(index, new_table, true)!
		}
	}
	catalog.storage.check_unique_constraints(new_table, rows)!
	catalog.storage.check_foreign_keys(mut conn, new_table, rows)!
}
