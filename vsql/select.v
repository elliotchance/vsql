// select.v contains the implementation for the SELECT statement.

module vsql

import time

fn execute_select(mut c Connection, stmt QueryExpression, params map[string]Value, elapsed_parse time.Duration, explain bool) ?Result {
	t := start_timer()

	c.open_read_connection() ?
	defer {
		c.release_read_connection()
	}

	mut plan := create_plan(stmt, params, c) ?

	if explain {
		return plan.explain(elapsed_parse)
	}

	rows := plan.execute([]Row{}) ?

	return new_result(plan.columns(), rows, elapsed_parse, t.elapsed())
}

fn transform_select_expressions(c &Connection, params map[string]Value, rows []Row, select_list SelectList, columns Columns) ?[]Row {
	// Expand "*" if needed so we have a distinct list of named columns to use
	// for the transformation.
	mut exprs := []DerivedColumn{}
	match select_list {
		AsteriskExpr {
			for column_name in columns {
				exprs << DerivedColumn{new_identifier('"$column_name"'), new_identifier('"$column_name"')}
			}
		}
		[]DerivedColumn {
			exprs = select_list.clone()
		}
	}

	mut returned_rows := []Row{cap: rows.len}
	mut col_num := 1
	mut column_names := []string{cap: exprs.len}
	mut first_row := true
	for row in rows {
		col_num = 1
		mut data := map[string]Value{}
		for expr in exprs {
			mut column_name := 'COL$col_num'
			if expr.as_clause.name != '' {
				column_name = expr.as_clause.name
			} else if expr.expr is Identifier {
				column_name = expr.expr.name
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
			id: row.id
			tid: row.tid
		}
	}

	return returned_rows
}
