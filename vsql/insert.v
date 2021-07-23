// insert.v contains the implementation for the INSERT statement.

module vsql

fn (mut c Connection) insert(stmt InsertStmt) ?Result {
	mut row := Row{
		data: map[string]Value{}
	}
	row.data[stmt.columns[0]] = stmt.values[0]

	c.storage.write_row(row, c.storage.tables[stmt.table_name]) ?

	return new_result_msg('INSERT 1')
}
