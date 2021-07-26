// select.v contains the implementation for the SELECT statement.

module vsql

fn (mut c Connection) query_select(stmt SelectStmt) ?Result {
	if stmt.from != '' {
		table_name := identifier_name(stmt.from)

		if table_name in c.storage.tables {
			table := c.storage.tables[table_name]

			mut rows := c.storage.read_rows(table.index) ?
			if stmt.where !is NoExpr {
				rows = where(rows, false, stmt.where) ?
			}

			return new_result(table.column_names(), rows)
		}

		return sqlstate_42p01(table_name)
	}

	mut data := map[string]Value{}
	mut col_num := 1
	mut cols := []string{cap: stmt.exprs.len}
	empty_row := Row{
		data: map[string]Value{}
	}
	for expr in stmt.exprs {
		column_name := 'COL$col_num'
		data[column_name] = eval_as_value(empty_row, expr) ?
		cols << column_name
		col_num++
	}

	return new_result(cols, [
		Row{
			data: data
		},
	])
}
