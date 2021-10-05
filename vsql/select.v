// select.v contains the implementation for the SELECT statement.

module vsql

import time

fn execute_select(mut c Connection, stmt SelectStmt, params map[string]Value, elapsed_parse time.Duration, explain bool) ?Result {
	t := start_timer()

	c.open_read_connection() ?
	defer {
		c.release_read_connection()
	}

	plan := create_plan(stmt, params, c) ?
	mut exprs := stmt.exprs

	if explain {
		return plan.explain(elapsed_parse)
	}

	// Execute the query.
	all_rows := plan.execute([]Row{}) ?

	// Transform into expressions.
	//
	// TODO(elliotchance): This isn't necessary if the VirtualTable relies on
	//  the Table and not the CreateTableStmt.
	first_operation := plan.operations[0]
	match first_operation {
		PrimaryKeyOperation {
			if exprs is AsteriskExpr {
				mut new_exprs := []DerivedColumn{}
				for column_name in first_operation.table.column_names() {
					new_exprs << DerivedColumn{Identifier{'"$column_name"'}, Identifier{'"$column_name"'}}
				}

				exprs = new_exprs
			}
		}
		TableOperation {
			if exprs is AsteriskExpr {
				mut new_exprs := []DerivedColumn{}
				for column_name in first_operation.table.column_names() {
					new_exprs << DerivedColumn{Identifier{'"$column_name"'}, Identifier{'"$column_name"'}}
				}

				exprs = new_exprs
			}
		}
		VirtualTableOperation {
			if exprs is AsteriskExpr {
				mut new_exprs := []DerivedColumn{}
				for table_element in first_operation.table.create_table_stmt.table_elements {
					if table_element is Column {
						new_exprs << DerivedColumn{Identifier{table_element.name}, Identifier{table_element.name}}
					}
				}

				exprs = new_exprs
			}
		}
		else {
			panic('invalid initial operation')
		}
	}

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
