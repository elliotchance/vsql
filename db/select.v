// select.v contains the implementation for the SELECT statement.

module vdb

fn (mut db Vdb) query_select(stmt SelectStmt) ?Result {
	if stmt.from != '' {
		if stmt.from in db.storage.tables {
			table := db.storage.tables[stmt.from]

			mut rows := db.storage.read_rows(table.index) ?
			if stmt.where.op != '' {
				rows = where(rows, false, stmt.where) ?
			}

			return new_result(table.column_names(), rows)
		}

		return sqlstate_42p01(stmt.from)
	}

	return new_result(['col1'], [
		Row{
			data: map{
				'col1': stmt.value
			}
		},
	])
}
