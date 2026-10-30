module vsql

// ISO/IEC 9075-2:2016(E), 11.26, <drop table constraint definition>
//
// Destroy a constraint on a table.

// The behavior is RESTRICT when it's not provided (the standard requires it),
// like DROP TABLE.
struct DropTableConstraintDefinition {
	name     Identifier
	behavior string // CASCADE or RESTRICT
}

// execute drops the constraint, which must be a constraint of the table. A
// FOREIGN KEY depends on the PRIMARY KEY or UNIQUE that has its referenced
// columns, so with RESTRICT that can't be dropped, and CASCADE drops the
// FOREIGN KEY too.
//
// The NOT NULL of a column in the PRIMARY KEY can't be dropped, but the NOT
// NULL of an identity column can (#790). Dropping the PRIMARY KEY doesn't drop
// the NOT NULL of its columns, because they're separate constraints (see
// check_constraints_view_rows). The rows are moved, because they're stored by
// their PRIMARY KEY, and they're written again when a NOT NULL is dropped (see
// replace_table_definition).
//
// ISO/IEC 9075-2:2016(E), 11.26, <drop table constraint definition>, Syntax Rules, 2, 3, 11.a, 11.d and 13.a
// ISO/IEC 9075-2:2016(E), 11.26, <drop table constraint definition>, General Rules, 1 and 6 to 8
fn (d DropTableConstraintDefinition) execute(mut conn Connection, mut catalog CatalogConnection, table Table) ! {
	kind, i := table.find_constraint(d.name)!

	mut new_table := Table{
		...table
	}
	match kind {
		.not_null {
			column := table.columns[i]
			if column.name.sub_entity_name in table.primary_key {
				return sqlstate_42601('column ${column.name.sub_entity_name} is in the PRIMARY KEY, so its NOT NULL cannot be dropped')
			}

			mut columns := table.columns.clone()
			columns[i] = Column{
				...column
				not_null: false
			}
			mut not_null_names := table.not_null_names.clone()
			not_null_names.delete(column.name.sub_entity_name)
			new_table = Table{
				...table
				columns:        columns
				not_null_names: not_null_names
			}
		}
		.primary_key {
			new_table = Table{
				...table
				primary_key:      []string{}
				primary_key_name: ''
			}
		}
		.unique {
			new_table = Table{
				...table
				unique_constraints: table.unique_constraints.filter(it.name != table.unique_constraints[i].name)
			}
		}
		.foreign_key {
			new_table = Table{
				...table
				foreign_keys: table.foreign_keys.filter(it.name != table.foreign_keys[i].name)
			}
		}
		.check {
			new_table = Table{
				...table
				check_constraints: table.check_constraints.filter(it.name.entity_name != table.check_constraints[i].name.entity_name)
			}
		}
	}

	if kind in [.primary_key, .unique] {
		unique_columns := if kind == .primary_key {
			table.primary_key
		} else {
			table.unique_constraints[i].columns
		}
		new_table = catalog.storage.drop_dependent_foreign_keys(table, new_table, unique_columns,
			d.behavior, d.name.entity_name)!
	}

	if kind in [.primary_key, .not_null] {
		replace_table_definition(mut conn, mut catalog, table, new_table)!
	} else {
		catalog.storage.update_table(new_table)!
	}
}

// drop_dependent_foreign_keys drops the FOREIGN KEYs that reference the unique
// columns of table, which are being dropped from its new definition (new_table),
// and returns new_table without them (a FOREIGN KEY of the table itself can be
// dependent). With RESTRICT, it's an error if there are any.
fn (mut f Storage) drop_dependent_foreign_keys(table Table, new_table Table, unique_columns []string, behavior string, name string) !Table {
	mut sorted := unique_columns.clone()
	sorted.sort()
	is_dependent := fn [table, sorted] (key ForeignKey) bool {
		mut columns := key.referenced_columns.clone()
		columns.sort()
		return key.referenced_table.storage_id() == table.name.storage_id() && columns == sorted
	}

	// The tables are sorted so that they're always changed in the same order.
	mut result := new_table
	mut names := f.tables.keys()
	names.sort()
	for table_name in names {
		mut referencing := if table_name == table.name.storage_id() {
			new_table
		} else {
			f.table(table_name)
		}
		keys := referencing.foreign_keys.filter(!is_dependent(it))
		if keys.len == referencing.foreign_keys.len {
			continue
		}
		if behavior == 'RESTRICT' {
			return sqlstate_2bp01('constraint ${requote_identifier(name)} on ${table.name}')
		}

		referencing.foreign_keys = keys
		if table_name == table.name.storage_id() {
			result = referencing
		} else {
			f.update_table(referencing)!
		}
	}

	return result
}
