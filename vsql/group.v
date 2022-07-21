// group.v contains operations for handing GROUP BY operations.

module vsql

struct GroupOperation {
	// select_exprs contains the original SELECT expressions, both the aggregate
	// and non-aggrgate expressions, such as "a, count(*)".
	//
	// It only works with []DerivedColumn because other forms of SelectList are
	// impossible to use with GROUP BY.
	select_exprs []DerivedColumn
	// group_exprs contains the expressions for the GROUP BY itself, such as
	// "a".
	//
	// The SQL standard doesn't actually allow anything other than a identifer
	// to be used in GROUP BY expressions, but well keep them as []Expr because
	// it's easier.
	group_exprs []Expr

	params map[string]Value
	conn   &Connection

	columns Columns
}

fn new_group_operation(select_exprs []DerivedColumn, group_exprs []Expr, params map[string]Value, conn &Connection, table Table) ?&GroupOperation {
	mut columns := []Column{}

	for expr in group_exprs {
		// TODO(elliotchance): This is a hack for now. Fix me later when we have
		//  multiple tables.
		name := expr.str().split('.')[1]
		columns << table.column(name)?
	}

	empty_row := new_empty_row(table.columns, table.name)
	for expr in select_exprs {
		if expr_is_agg(conn, expr.expr, empty_row, params)? {
			columns << Column{expr.expr.pstr(params), eval_as_type(conn, empty_row, expr.expr,
				params)?, false}

			// We need verify the expression type for the argument to the
			// aggregate function is valid.
			if expr.expr is CallExpr {
				expr_type := eval_as_type(conn, empty_row, expr.expr.args[0], params)?
				conn.find_function(expr.expr.function_name, [expr_type])?
			}
		}
	}

	return &GroupOperation{select_exprs, group_exprs, params, conn, columns}
}

fn (o &GroupOperation) str() string {
	return 'GROUP BY ($o.columns())'
}

fn (o &GroupOperation) columns() Columns {
	return o.columns
}

fn (o &GroupOperation) execute(rows []Row) ?[]Row {
	// Create the grouped sets.
	mut sets := [][]Row{}

	if rows.len > 0 {
		sets << []Row{}
	}

	for row in rows {
		if sets[sets.len - 1].len == 0 {
			sets[sets.len - 1] << row
			continue
		}

		mut equal := true
		for expr in o.group_exprs {
			left := eval_as_value(o.conn, sets[sets.len - 1][sets[sets.len - 1].len - 1],
				expr, o.params)?
			right := eval_as_value(o.conn, row, expr, o.params)?

			cmp, _ := left.cmp(right)?
			if cmp != 0 {
				equal = false
				break
			}
		}

		if equal {
			sets[sets.len - 1] << row
		} else {
			sets << [row]
		}
	}

	// Perform the aggregations functions.
	for expr in o.select_exprs {
		if expr_is_agg(o.conn, expr.expr, rows[0], o.params)? {
			key := expr.expr.pstr(o.params)
			for mut set in sets {
				match expr.expr {
					CallExpr {
						mut values := []Value{}
						for row in set {
							values << eval_as_value(o.conn, row, expr.expr.args[0], o.params)?
						}

						func := o.conn.find_function(expr.expr.function_name, [values[0].typ])?
						set[0].data[key] = func.func(values)?
					}
					CountAllExpr {
						set[0].data[key] = new_integer_value(set.len)
					}
					else {
						return sqlstate_42601('invalid set function: $expr.expr')
					}
				}
			}
		}
	}

	// Collapse to final set.
	mut final_rows := []Row{}
	for set in sets {
		final_rows << set[0]
	}

	return final_rows
}
