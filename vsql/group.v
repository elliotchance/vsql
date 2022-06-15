// group.v contains operations for handing GROUP BY operations.

module vsql

struct GroupOperation {
	select_exprs []DerivedColumn
	group_exprs  []Expr
	params       map[string]Value
	conn         &Connection
	columns      Columns
}

fn new_group_operation(select_exprs []DerivedColumn, group_exprs []Expr, params map[string]Value, conn &Connection, columns Columns) &GroupOperation {
	return &GroupOperation{select_exprs, group_exprs, params, conn, columns}
}

fn (o &GroupOperation) str() string {
	mut exprs := []string{}
	for expr in o.select_exprs {
		if !expr_is_agg(o.conn, expr.expr) or { false } {
			exprs << expr.expr.pstr(o.params)
		}
	}

	agg_destinations := o.group_columns().join(', ')

	if exprs.len == 0 {
		return 'GROUP BY ($agg_destinations)'
	}

	return 'GROUP BY ${exprs.join(', ')} ($agg_destinations)'
}

// The input and output colums of a GROUP BY operation is always the same. This
// is because the columns that contain aggregation expressions (such as
// COUNT(*)) are already resolved for their type and location (that is, the
// order they appear in).
//
// The GROUP BY is basically "back filling" these values onto the same (or less)
// rows but the columns don't change.
fn (o &GroupOperation) columns() Columns {
	return o.columns
}

// The group colums are those that contains aggregations expressions. These will
// be the ones we actually evaulate and fill back into the result set.
fn (o &GroupOperation) group_columns() []string {
	mut columns := []string{}
	for i, expr in o.select_exprs {
		if expr_is_agg(o.conn, expr.expr) or { false } {
			columns << expr.expr.pstr(o.params) + ' AS ' + o.columns[i].name
		}
	}

	return columns
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
	for i, expr in o.select_exprs {
		if expr_is_agg(o.conn, expr.expr) or { false } {
			for mut set in sets {
				match expr.expr {
					CallExpr {
						func := o.conn.funcs[expr.expr.function_name] or {
							return sqlstate_42883(expr.expr.function_name)
						}

						mut values := []Value{}
						for row in set {
							values << row.data[o.columns[i].name]
						}

						set[0].data[o.columns[i].name] = func.func(values)?
					}
					CountAllExpr {
						set[0].data[o.columns[i].name] = new_integer_value(set.len)
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
