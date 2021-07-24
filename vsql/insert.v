// insert.v contains the implementation for the INSERT statement.

module vsql

fn (mut c Connection) insert(stmt InsertStmt) ?Result {
	mut row := Row{
		data: map[string]Value{}
	}

	if stmt.columns.len < stmt.values.len {
		return sqlstate_42601('INSERT has more values than columns')
	}

	if stmt.columns.len > stmt.values.len {
		return sqlstate_42601('INSERT has less values than columns')
	}

	table_name := identifier_name(stmt.table_name)
	if table_name !in c.storage.tables {
		return sqlstate_42p01(table_name) // table not found
	}

	table := c.storage.tables[table_name]
	for i, column in stmt.columns {
		column_name := identifier_name(column)
		table_column := table.column(column_name) ?
		value := cast('for column $column_name', stmt.values[i], table_column.typ) ?
		row.data[column_name] = value
	}

	c.storage.write_row(row, table) ?

	return new_result_msg('INSERT 1')
}
