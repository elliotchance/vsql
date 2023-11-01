module vsql

// ISO/IEC 9075-2:2016(E), 7.13, <group by clause>
//
// # Function
//
// Specify a grouped table derived by the application of the <group by clause>
// to the result of the previously specified clause.
//
// # Format
//~
//~ <group by clause> /* []Identifier */ ::=
//~     GROUP BY <grouping element list>   -> group_by_clause
//~
//~ <grouping element list> /* []Identifier */ ::=
//~     <grouping element>                                   -> grouping_element_list_1
//~   | <grouping element list> <comma> <grouping element>   -> grouping_element_list_2
//~
//~ <grouping element> /* Identifier */ ::=
//~     <ordinary grouping set>
//~
//~ <ordinary grouping set> /* Identifier */ ::=
//~     <grouping column reference>
//~
//~ <grouping column reference> /* Identifier */ ::=
//~     <column reference>

fn parse_group_by_clause(e []Identifier) ![]Identifier {
	return e
}

fn parse_grouping_element_list_1(expr Identifier) ![]Identifier {
	return [expr]
}

fn parse_grouping_element_list_2(element_list []Identifier, element Identifier) ![]Identifier {
	mut new_list := element_list.clone()
	new_list << element

	return new_list
}

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

	empty_row := new_empty_row(table.columns, table.name.str())
	for expr in select_exprs {
		if is_agg(expr.expr)! {
			columns << Column{Identifier{
				custom_id: expr.expr.pstr(params)
			}, expr.expr.eval_type(conn, empty_row, params)!, false}

			// We need verify the expression type for the argument to the
			// aggregate function is valid.
			if expr.expr is CommonValueExpression {
				if expr.expr is CharacterValueExpression {
					if expr.expr is CharacterPrimary {
						if expr.expr is CharacterValueFunction {
							if expr.expr is RoutineInvocation {
								expr_type := expr.expr.args[0].eval_type(conn, empty_row,
									params)!
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
			left := expr.eval(mut o.conn, sets[sets.len - 1][sets[sets.len - 1].len - 1],
				o.params)!
			right := expr.eval(mut o.conn, row, o.params)!

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
		if is_agg(expr.expr)! {
			key := expr.expr.pstr(o.params)
			for mut set in sets {
				mut valid := false
				if expr.expr is CommonValueExpression {
					if expr.expr is DatetimePrimary {
						if expr.expr is ValueExpressionPrimary {
							if expr.expr is NonparenthesizedValueExpressionPrimary {
								if expr.expr is AggregateFunction {
									if expr.expr is AggregateFunctionCount {
										set[0].data[key] = new_integer_value(set.len)
										valid = true
									} else if expr.expr is RoutineInvocation {
										e := expr.expr
										mut values := []Value{}
										for row in set {
											values << e.args[0].eval(mut o.conn, row,
												o.params)!
										}

										func := o.conn.find_function(e.function_name,
											[values[0].typ])!
										set[0].data[key] = func.func(values)!
										valid = true
									}
								}
							}
						}
					}
				}

				if !valid {
					return sqlstate_42601('invalid set function: ${expr.expr}')
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
