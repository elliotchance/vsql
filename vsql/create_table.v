// create_table.v contains the implementation for the CREATE TABLE statement.

module vsql

// TODO(elliotchance): A table is allowed to have zero columns.

fn (mut c Connection) create_table(stmt CreateTableStmt) ?Result {
	if stmt.table_name in c.storage.tables {
		return sqlstate_42p07(stmt.table_name) // duplicate table
	}

	if is_reserved_word(stmt.table_name) {
		return sqlstate_42601('table name cannot be reserved word: $stmt.table_name.to_upper()')
	}

	for column in stmt.columns {
		if is_reserved_word(column.name) {
			return sqlstate_42601('column name cannot be reserved word: $column.name.to_upper()')
		}
	}

	c.storage.create_table(stmt.table_name, stmt.columns) ?

	return new_result_msg('CREATE TABLE 1')
}
