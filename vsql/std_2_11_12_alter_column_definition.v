module vsql

// ISO/IEC 9075-2:2016(E), 11.12, <alter column definition>
//
// Change a column and its definition.

// SET DEFAULT, DROP DEFAULT and the <alter identity column specification> are
// the only <alter column action>s that are supported.
type AlterColumnAction = AlterIdentityColumnSpecification
	| DropColumnDefaultClause
	| SetColumnDefaultClause

struct AlterColumnDefinition {
	column_name Identifier
	action      AlterColumnAction
}

// execute changes the descriptor of the column (General Rule 1). Only the
// definition of the table is changed, the existing rows keep their values.
fn (d AlterColumnDefinition) execute(mut conn Connection, mut catalog CatalogConnection, table Table) ! {
	column := table.column(d.column_name.sub_entity_name)!

	// ISO/IEC 9075-2:2016(E), 11.12, <alter column definition>, Syntax Rules 6
	// and 7
	is_identity := column.identity != none
	if is_identity != (d.action is AlterIdentityColumnSpecification) {
		return sqlstate_42601(if is_identity {
			'cannot change the default of identity column ${column.name.sub_entity_name}'
		} else {
			'column ${column.name.sub_entity_name} is not an identity column'
		})
	}

	// ISO/IEC 9075-2:2016(E), 11.12, <alter column definition>, Syntax Rule 9
	if column.generated != none && d.action is SetColumnDefaultClause {
		return sqlstate_42601('cannot set the default of generated column ${column.name.sub_entity_name}')
	}

	mut sequence := ?Sequence(none)
	new_column := match d.action {
		AlterIdentityColumnSpecification {
			new_column, new_sequence := d.action.execute(mut conn, table, column)!
			sequence = new_sequence
			new_column
		}
		DropColumnDefaultClause {
			d.action.execute(column)!
		}
		SetColumnDefaultClause {
			d.action.execute(mut conn, column)!
		}
	}

	catalog.storage.update_table(Table{
		...table
		columns: table.columns.map(if it.name.sub_entity_name == column.name.sub_entity_name {
			new_column
		} else {
			it
		})
	})!
	if s := sequence {
		catalog.storage.update_identity(table.id, s)!
	}
}
