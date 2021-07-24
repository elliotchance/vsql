// select.v contains the implementation for the SELECT statement.

module vsql

fn (mut c Connection) query_select(stmt SelectStmt) ?Result {
	if stmt.from != '' {
		table_name := identifier_name(stmt.from)

		if table_name in c.storage.tables {
			table := c.storage.tables[table_name]

			mut rows := c.storage.read_rows(table.index) ?
			if stmt.where.op != '' {
				rows = where(rows, false, stmt.where) ?
			}

			return new_result(table.column_names(), rows)
		}

		return sqlstate_42p01(table_name)
	}

	return new_result(['COL1'], [
		Row{
			data: map{
				'COL1': stmt.value
			}
		},
	])
}
