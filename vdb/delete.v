// delete.v contains the implementation for the DELETE statement.

module vdb

fn (mut db Vdb) delete(stmt DeleteStmt) ?Result {
	if stmt.table_name !in db.storage.tables {
		return sqlstate_42p01(stmt.table_name) // table not found
	}

	table := db.storage.tables[stmt.table_name]
	mut rows := db.storage.read_rows(table.index) ?

	mut deleted := 0
	for row in rows {
		mut ok := true
		if stmt.where.op != '' {
			ok = eval(row, stmt.where) ?
		}

		if ok {
			deleted++
			db.storage.delete_row(row) ?
		}
	}

	return new_result_msg('DELETE $deleted')
}
