// delete.v contains the implementation for the DELETE statement.

module vsql

fn (mut c Connection) delete(stmt DeleteStmt) ?Result {
	if stmt.table_name !in c.storage.tables {
		return sqlstate_42p01(stmt.table_name) // table not found
	}

	table := c.storage.tables[stmt.table_name]
	mut rows := c.storage.read_rows(table.index) ?

	mut deleted := 0
	for row in rows {
		mut ok := true
		if stmt.where.op != '' {
			ok = eval(row, stmt.where) ?
		}

		if ok {
			deleted++
			c.storage.delete_row(row) ?
		}
	}

	return new_result_msg('DELETE $deleted')
}
