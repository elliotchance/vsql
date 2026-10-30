module vsql

// ISO/IEC 9075-2:2016(E), 11.23, <drop column definition>
//
// Destroy a column of a base table.

// The behavior is RESTRICT when it's not provided (the standard requires it),
// like DROP CONSTRAINT.
struct DropColumnDefinition {
	column_name Identifier
	behavior    string // CASCADE or RESTRICT
}

// execute drops the column and its values from every row. It can't be the only
// column of the table.
//
// A constraint of the table that only uses the column (its NOT NULL, a CHECK
// or a single column PRIMARY KEY or UNIQUE) is dropped with it. Any other
// constraint that uses the column can only be dropped with CASCADE, otherwise
// it's an error. That's a PRIMARY KEY or UNIQUE of more than one column, a
// CHECK that also uses other columns, or a FOREIGN KEY that has the column as
// one of its columns or referenced columns (of any table), because it also
// uses the columns of the other side.
//
// A generated column whose generation expression uses the column can also only
// be dropped with CASCADE, which drops it first.
//
// ISO/IEC 9075-2:2016(E), 11.23, <drop column definition>, Syntax Rules, 4, 7.b and 7.f
// ISO/IEC 9075-2:2016(E), 11.23, <drop column definition>, General Rules, 3 to 8
//
// The rows are written again, because the values of a row are stored in the
// order of the columns (see Row.bytes). The current value of the sequence of
// an identity column is dropped with it.
fn (d DropColumnDefinition) execute(mut conn Connection, mut catalog CatalogConnection, original_table Table) ! {
	mut table := original_table
	column := table.column(d.column_name.sub_entity_name)!
	name := column.name.sub_entity_name
	mut generated_columns := []Column{}
	for generated_column in table.columns {
		generated := generated_column.generated or { continue }
		if generated_column.name.sub_entity_name != name
			&& name in generated.columns(mut conn, table, generated_column)! {
			generated_columns << generated_column
		}
	}
	if table.columns.len - generated_columns.len == 1 {
		return sqlstate_42601('cannot drop the only column of ${table.name}')
	}
	if generated_columns.len > 0 && d.behavior == 'RESTRICT' {
		return sqlstate_2bp01('column ${requote_identifier(generated_columns[0].name.sub_entity_name)} on ${table.name}')
	}
	for generated_column in generated_columns {
		DropColumnDefinition{generated_column.name, 'CASCADE'}.execute(mut conn, mut catalog,
			table)!
		table = catalog.storage.table(table.name.storage_id())
	}

	// The constraints that need CASCADE, as the table and constraint names.
	mut dependent := [][]string{}

	mut primary_key := table.primary_key.clone()
	mut primary_key_name := table.primary_key_name
	if name in table.primary_key {
		if table.primary_key.len > 1 {
			dependent << [table.name.str(), table.primary_key_name]
		}
		primary_key = []string{}
		primary_key_name = ''
	}

	mut unique_constraints := []UniqueConstraint{}
	for constraint in table.unique_constraints {
		if name !in constraint.columns {
			unique_constraints << constraint
		} else if constraint.columns.len > 1 {
			dependent << [table.name.str(), constraint.name]
		}
	}

	mut check_constraints := []CheckConstraintDefinition{}
	for constraint in table.check_constraints {
		check_columns := constraint.columns(mut conn, table)!
		if name !in check_columns {
			check_constraints << constraint
		} else if check_columns.len > 1 {
			dependent << [table.name.str(), constraint.name.entity_name]
		}
	}

	// The tables are sorted so that the same error is always returned, and
	// they're always changed in the same order.
	mut referencing_tables := []Table{}
	mut table_names := catalog.storage.tables.keys()
	table_names.sort()
	mut foreign_keys := []ForeignKey{}
	for table_name in table_names {
		mut referencing := catalog.storage.table(table_name)
		is_table := table_name == table.name.storage_id()
		mut keys := []ForeignKey{}
		for key in referencing.foreign_keys {
			is_referenced := key.referenced_table.storage_id() == table.name.storage_id()
				&& name in key.referenced_columns
			if !is_referenced && !(is_table && name in key.columns) {
				keys << key
				continue
			}

			// Only a FOREIGN KEY of the table that references the same column
			// of the table doesn't use any other columns.
			if !(is_table && is_referenced && key.columns.all(it == name)
				&& key.referenced_columns.all(it == name)) {
				dependent << [referencing.name.str(), key.name]
			}
		}

		if is_table {
			foreign_keys = keys.clone()
		} else if keys.len != referencing.foreign_keys.len {
			referencing.foreign_keys = keys
			referencing_tables << referencing
		}
	}

	if dependent.len > 0 && d.behavior == 'RESTRICT' {
		return sqlstate_2bp01('constraint ${requote_identifier(dependent[0][1])} on ${dependent[0][0]}')
	}

	columns := table.columns.filter(it.name.sub_entity_name != name)
	mut not_null_names := table.not_null_names.clone()
	not_null_names.delete(name)
	new_table := Table{
		...table
		columns:            columns
		primary_key:        primary_key
		primary_key_name:   primary_key_name
		not_null_names:     not_null_names
		unique_constraints: unique_constraints
		check_constraints:  check_constraints
		foreign_keys:       foreign_keys
	}

	for referencing in referencing_tables {
		catalog.storage.update_table(referencing)!
	}
	replace_table_definition(mut conn, mut catalog, table, new_table)!
	if _ := column.identity {
		catalog.storage.delete_identity(table.id)!
	}
}
