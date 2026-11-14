module vsql

// ISO/IEC 9075-2:2023, 11.12, <alter column definition>
//
// Change a column and its definition.

// SET DEFAULT, DROP DEFAULT, SET NOT NULL, DROP NOT NULL, SET DATA TYPE and the
// <alter identity column specification> are the only <alter column action>s
// that are supported.
type AlterColumnAction = AlterColumnDataTypeClause
	| AlterIdentityColumnSpecification
	| DropColumnDefaultClause
	| DropColumnNotNullClause
	| SetColumnDefaultClause
	| SetColumnNotNullClause

struct AlterColumnDefinition {
	column_name Identifier
	action      AlterColumnAction
}

// execute changes the descriptor of the column, which must be a column of the
// table. Only the definition of the table is changed, the existing rows keep
// their values, unless the data type or NOT NULL changes, which writes every row
// again (and checks a new NOT NULL).
//
// ISO/IEC 9075-2:2023, 11.12, <alter column definition>, Syntax Rules, 4
// ISO/IEC 9075-2:2023, 11.12, <alter column definition>, General Rules, 1
fn (d AlterColumnDefinition) execute(mut conn Connection, mut catalog CatalogConnection, table Table) ! {
	column := table.column(d.column_name.sub_entity_name)!

	// ISO/IEC 9075-2:2023, 11.12, <alter column definition>, Syntax Rules, 6 and 7
	is_identity := column.identity != none
	if is_identity != (d.action is AlterIdentityColumnSpecification) {
		return sqlstate_42601(if is_identity {
			'cannot change the ${match d.action {
				AlterColumnDataTypeClause { 'data type' }
				DropColumnNotNullClause, SetColumnNotNullClause { 'NOT NULL' }
				else { 'default' }
			}} of identity column ${column.name.sub_entity_name}'
		} else {
			'column ${column.name.sub_entity_name} is not an identity column'
		})
	}

	// ISO/IEC 9075-2:2023, 11.12, <alter column definition>, Syntax Rules, 9
	if column.generated != none && d.action is SetColumnDefaultClause {
		return sqlstate_42601('cannot set the default of generated column ${column.name.sub_entity_name}')
	}

	mut sequence := ?Sequence(none)
	new_column := match d.action {
		AlterColumnDataTypeClause {
			d.action.execute(mut conn, table, column)!
		}
		AlterIdentityColumnSpecification {
			new_column, new_sequence := d.action.execute(mut conn, table, column)!
			sequence = new_sequence
			new_column
		}
		DropColumnDefaultClause {
			d.action.execute(column)!
		}
		DropColumnNotNullClause {
			d.action.execute(table, column)!
		}
		SetColumnDefaultClause {
			d.action.execute(mut conn, column)!
		}
		SetColumnNotNullClause {
			d.action.execute(column)
		}
	}

	mut new_table := Table{
		...table
		columns: table.columns.map(if it.name.sub_entity_name == column.name.sub_entity_name {
			new_column
		} else {
			it
		})
	}
	if new_column.not_null != column.not_null {
		// The constraint of a new NOT NULL gets a name, and a dropped one loses
		// its name.
		//
		// ISO/IEC 9075-2:2023, 11.15, <set column not null clause>, General Rules, 1.b, 1.c and 1.d
		// ISO/IEC 9075-2:2023, 11.16, <drop column not null clause>, General Rules, 1.b and 1.c
		new_table.not_null_names = table.not_null_names.clone()
		new_table.not_null_names.delete(column.name.sub_entity_name)
		new_table.name_constraints(catalog.storage.schema_constraint_names(table.name),
			catalog.storage.schema_index_names(table.name))!
	}
	if new_column.typ != column.typ || new_column.not_null != column.not_null {
		replace_table_definition(mut conn, mut catalog, table, new_table)!
	} else {
		catalog.storage.update_table(new_table)!
	}
	if s := sequence {
		catalog.storage.update_identity(table.id, s)!
	}
}
