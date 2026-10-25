module vsql

// ISO/IEC 9075-2:2016(E), 8.4, <in predicate>
//
// Specify a quantified comparison.

// InPredicate is "x IN (a, b, ...)" or, when there's a subquery,
// "x IN (SELECT ...)".
struct InPredicate {
	not      bool
	expr     RowValueConstructorPredicand
	values   []RowValueConstructorPredicand
	subquery ?Subquery
}

fn (e InPredicate) pstr(params map[string]Value) string {
	mut values := ''
	if subquery := e.subquery {
		values = subquery.pstr(params)
	} else {
		mut list := []string{}
		for value in e.values {
			list << value.pstr(params)
		}
		values = '(${list.join(', ')})'
	}

	return '${e.expr.pstr(params)} ' + if e.not {
		'NOT '
	} else {
		''
	} + 'IN ${values}'
}

fn (e InPredicate) compile(mut c Compiler) !CompileResult {
	compiled_expr := e.expr.compile(mut c)!
	mut contains_agg := compiled_expr.contains_agg
	mut compiled_values := []CompileResult{}
	for value in e.values {
		compiled := value.compile(mut c)!
		c.check_time_zone_comparison(compiled_expr.typ, compiled.typ)!
		contains_agg = contains_agg || compiled.contains_agg
		compiled_values << compiled
	}

	mut plan := ?SubqueryPlan(none)
	if subquery := e.subquery {
		subquery_plan := subquery.plan_column(mut c)!
		c.check_time_zone_comparison(compiled_expr.typ, subquery_plan.plan.columns()[0].typ)!
		contains_agg = contains_agg || subquery_plan.contains_agg
		plan = subquery_plan
	}

	return CompileResult{
		run:          fn [e, compiled_expr, compiled_values, plan] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := compiled_expr.run(mut conn, data, params)!

			mut values := []Value{}
			if subquery_plan := plan {
				values = subquery_values(mut conn, subquery_plan, data)!
			}
			for compiled_value in compiled_values {
				values << compiled_value.run(mut conn, data, params)!
			}

			// ISO/IEC 9075-2:2016(E), 8.4, <in predicate>, Syntax Rules 2, 4 and 5:
			//
			//   RVC IN (A, B, C) is RVC = ANY (VALUES A, B, C)
			//   RVC NOT IN IPV is NOT (RVC IN IPV)
			//   RVC IN IPV is RVC = ANY IPV
			//
			// So the result is TRUE if any value is equal, FALSE if every value is
			// not equal (or there are no values) and otherwise UNKNOWN.
			mut result := quantified_comparison(conn, expr, .equal, false, values)!
			if e.not {
				result = truth_not(result)
			}

			return result.value()
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: contains_agg
	}
}
