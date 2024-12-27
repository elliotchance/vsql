module vsql

// ISO/IEC 9075-2:2016(E), 7.13, <group by clause>
//
// Specify a grouped table derived by the application of the <group by clause>
// to the result of the previously specified clause.

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
	// to be used in GROUP BY expressions, but well keep them as []Identifier
	// because it's easier.
	group_exprs []Identifier

	params  map[string]Value
	columns Columns
mut:
	conn &Connection
}

fn new_group_operation(select_exprs []DerivedColumn, group_exprs []Identifier, params map[string]Value, mut conn Connection, table Table) !&GroupOperation {
	mut columns := []Column{}

	for expr in group_exprs {
		// TODO(elliotchance): This is a hack for now. Fix me later when we have
		//  multiple tables.
		name := expr.str().split('.')
		columns << table.column(name[name.len - 1])!
	}

	mut c := Compiler{
		conn:   conn
		params: params
	}
	for expr in select_exprs {
		compiled_expr := expr.expr.compile(mut c)!
		if compiled_expr.contains_agg {
			columns << Column{Identifier{
				custom_id:  expr.expr.pstr(params)
				custom_typ: compiled_expr.typ
			}, compiled_expr.typ, false}

			// We need verify the expression type for the argument to the
			// aggregate function is valid.
			if expr.expr is CommonValueExpression {
				if expr.expr is CharacterValueExpression {
					if expr.expr is CharacterPrimary {
						if expr.expr is CharacterValueFunction {
							if expr.expr is RoutineInvocation {
								expr_type := expr.expr.args[0].compile(mut c)!.typ
								conn.find_function(expr.expr.function_name, [
									expr_type,
								])!
							}
						}
					}
				}
			}
		}
	}

	return &GroupOperation{select_exprs, group_exprs, params, columns, conn}
}

fn (o &GroupOperation) str() string {
	return 'GROUP BY (${o.columns()})'
}

fn (o &GroupOperation) columns() Columns {
	return o.columns
}

fn (mut o GroupOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
	}

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
			left := expr.compile(mut c)!.run(mut o.conn, sets[sets.len - 1][sets[sets.len - 1].len - 1],
				o.params)!
			right := expr.compile(mut c)!.run(mut o.conn, row, o.params)!

			if left.is_null && right.is_null {
				continue
			}

			cmp := compare(left, right)!
			if cmp != .is_equal {
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
		if expr.expr.compile(mut c)!.contains_agg {
			key := expr.expr.pstr(o.params)
			for mut set in sets {
				mut valid := false
				if expr.expr is BooleanValueExpression {
					expr2 := expr.expr.term.factor.expr
					if expr2 is BooleanPredicand {
						if expr2 is NonparenthesizedValueExpressionPrimary {
							if expr2 is AggregateFunction {
								if expr2 is AggregateFunctionCount {
									set[0].data[key] = new_integer_value(set.len)
									valid = true
								} else if expr2 is RoutineInvocation {
									mut values := []Value{}
									for row in set {
										values << expr2.args[0].compile(mut c)!.run(mut o.conn,
											row, o.params)!
									}

									func := o.conn.find_function(expr2.function_name,
										[values[0].typ])!
									set[0].data[key] = func.func(values)!
									valid = true
								}
							}
						}
					}
				}

				if !valid {
					return sqlstate_42601('invalid set function: ${expr.expr.pstr(o.params)}')
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
