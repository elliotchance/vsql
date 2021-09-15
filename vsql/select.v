// select.v contains the implementation for the SELECT statement.

module vsql

import time

fn execute_select(mut c Connection, stmt SelectStmt, params map[string]Value, elapsed_parse time.Duration) ?Result {
	t := start_timer()

	// Find all rows first.
	mut all_rows := []Row{}
	mut exprs := stmt.exprs

	table_name := identifier_name(stmt.from)

	// Check virtual table first.
	if table_name in c.virtual_tables {
		mut vt := c.virtual_tables[table_name]
		vt.reset()
		for !vt.is_done {
			vt.data(mut vt) ?
		}
		all_rows = vt.rows

		if exprs is AsteriskExpr {
			mut new_exprs := []DerivedColumn{}
			for col in vt.create_table_stmt.columns {
				new_exprs << DerivedColumn{Identifier{col.name}, Identifier{col.name}}
			}

			exprs = new_exprs
		}

		// TODO(elliotchance): Virtual tables don't implement OFFSET/FETCH.
	}
	// Now check for a regular table.
	else if table_name in c.storage.tables {
		table := c.storage.tables[table_name]

		if exprs is AsteriskExpr {
			mut new_exprs := []DerivedColumn{}
			for column_name in table.column_names() {
				new_exprs << DerivedColumn{Identifier{'"$column_name"'}, Identifier{'"$column_name"'}}
			}

			exprs = new_exprs
		}

		mut offset := 0
		if stmt.offset !is NoExpr {
			offset = int((eval_as_value(c, Row{}, stmt.offset, params) ?).f64_value)
		}

		mut fetch := -1
		if stmt.fetch !is NoExpr {
			fetch = int((eval_as_value(c, Row{}, stmt.fetch, params) ?).f64_value)
		}

		all_rows = c.storage.read_rows(table.name, offset) ?
		if stmt.where is NoExpr {
			if fetch >= 0 && all_rows.len > fetch {
				all_rows = all_rows[..fetch]
			}
		} else {
			all_rows = where(c, all_rows, false, stmt.where, fetch, params) ?
		}
	} else {
		return sqlstate_42p01(table_name)
	}

	// Transform into expressions.
	mut returned_rows := []Row{cap: all_rows.len}
	mut col_num := 1
	mut column_names := []string{cap: (exprs as []DerivedColumn).len}
	mut first_row := true
	for row in all_rows {
		col_num = 1
		mut data := map[string]Value{}
		for expr in exprs as []DerivedColumn {
			mut column_name := 'COL$col_num'
			if expr.as_clause.name != '' {
				column_name = identifier_name(expr.as_clause.name)
			}
			if expr.expr is Identifier {
				column_name = identifier_name(expr.expr.name)
			}

			if first_row {
				column_names << column_name
			}

			data[column_name] = eval_as_value(c, row, expr.expr, params) ?
			col_num++
		}

		first_row = false
		returned_rows << Row{
			data: data
		}
	}

	return new_result(column_names, returned_rows, elapsed_parse, t.elapsed())
}
