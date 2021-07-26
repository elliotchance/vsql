// delete.v contains the implementation for the DELETE statement.

module vsql

fn (mut c Connection) delete(stmt DeleteStmt) ?Result {
	table_name := identifier_name(stmt.table_name)

	if table_name !in c.storage.tables {
		return sqlstate_42p01(table_name) // table not found
	}

	table := c.storage.tables[table_name]
	mut rows := c.storage.read_rows(table.index) ?

	mut deleted := 0
	for row in rows {
		mut ok := true
		if stmt.where !is NoExpr {
			ok = eval_as_bool(row, stmt.where) ?
		}

		if ok {
			deleted++
			c.storage.delete_row(row) ?
		}
	}

	return new_result_msg('DELETE $deleted')
}
