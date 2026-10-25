module vsql

// ISO/IEC 9075-2:2016(E), 11.12, <alter column definition>
//
// Change a column and its definition.

// SET DEFAULT and DROP DEFAULT are the only <alter column action>s that are
// supported.
type AlterColumnAction = DropColumnDefaultClause | SetColumnDefaultClause

struct AlterColumnDefinition {
	column_name Identifier
	action      AlterColumnAction
}

// execute changes the descriptor of the column (General Rule 1). Only the
// definition of the table is changed, the existing rows keep their values.
fn (d AlterColumnDefinition) execute(mut conn Connection, mut catalog CatalogConnection, table Table) ! {
	column := table.column(d.column_name.sub_entity_name)!
	new_column := match d.action {
		DropColumnDefaultClause { d.action.execute(column)! }
		SetColumnDefaultClause { d.action.execute(mut conn, column)! }
	}

	catalog.storage.update_table(Table{
		...table
		columns: table.columns.map(if it.name.sub_entity_name == column.name.sub_entity_name {
			new_column
		} else {
			it
		})
	})!
}
