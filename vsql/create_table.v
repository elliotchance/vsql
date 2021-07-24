// create_table.v contains the implementation for the CREATE TABLE statement.

module vsql

// TODO(elliotchance): A table is allowed to have zero columns.

fn (mut c Connection) create_table(stmt CreateTableStmt) ?Result {
	table_name := identifier_name(stmt.table_name)

	if table_name in c.storage.tables {
		return sqlstate_42p07(table_name) // duplicate table
	}

	if is_reserved_word(table_name) {
		return sqlstate_42601('table name cannot be reserved word: $table_name')
	}

	mut columns := []Column{cap: stmt.columns.len}
	for column in stmt.columns {
		column_name := identifier_name(column.name)

		if is_reserved_word(column.name) {
			return sqlstate_42601('column name cannot be reserved word: $column_name')
		}

		columns << Column{column_name, column.typ}
	}

	c.storage.create_table(table_name, columns) ?

	return new_result_msg('CREATE TABLE 1')
}
