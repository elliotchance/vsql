// insert.v contains the implementation for the INSERT statement.

module vdb

fn (mut db Vdb) insert(stmt InsertStmt) ?Result {
	mut row := Row{
		data: map[string]Value{}
	}
	row.data[stmt.columns[0]] = stmt.values[0]

	db.storage.write_row(row, db.storage.tables[stmt.table_name]) ?

	return new_result_msg('INSERT 1')
}
