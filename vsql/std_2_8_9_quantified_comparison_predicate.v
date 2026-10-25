module vsql

// ISO/IEC 9075-2:2016(E), 8.9, <quantified comparison predicate>
//
// Specify a quantified comparison.

// QuantifiedComparisonPredicate is "x <op> ALL (SELECT ...)", or SOME (or ANY)
// when all is false.
struct QuantifiedComparisonPredicate {
	expr     RowValueConstructorPredicand
	op       ComparisonOperator
	all      bool
	subquery Subquery
}

fn (e QuantifiedComparisonPredicate) pstr(params map[string]Value) string {
	quantifier := if e.all { 'ALL' } else { 'SOME' }

	return '${e.expr.pstr(params)} ${e.op} ${quantifier} ${e.subquery.pstr(params)}'
}

fn (e QuantifiedComparisonPredicate) compile(mut c Compiler) !CompileResult {
	compiled_expr := e.expr.compile(mut c)!
	plan := e.subquery.plan_column(mut c)!
	c.check_time_zone_comparison(compiled_expr.typ, plan.plan.columns()[0].typ)!

	return CompileResult{
		run:          fn [e, compiled_expr, plan] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := compiled_expr.run(mut conn, data, params)!
			values := subquery_values(mut conn, plan, data)!

			return quantified_comparison(conn, expr, e.op, e.all, values)!.value()
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_expr.contains_agg
	}
}

// quantified_comparison compares expr with each of the values. Every value is
// compared (rather than stopping at the first result that decides it) so that
// an incomparable value is always an error, wherever it is.
//
// ISO/IEC 9075-2:2016(E), 8.9, <quantified comparison predicate>, General Rule 2
fn quantified_comparison(conn &Connection, expr Value, op ComparisonOperator, all bool, values []Value) !Truth {
	// a) and d): An empty table is TRUE for ALL and FALSE for SOME.
	mut result := if all { Truth.is_true } else { Truth.is_false }
	for value in values {
		truth := op.truth(compare(conn, expr, value)!)

		// b) ALL is FALSE if any comparison is FALSE, and c) SOME is TRUE if any
		// comparison is TRUE. e) Otherwise, it's UNKNOWN.
		result = if all { truth_and(result, truth) } else { truth_or(result, truth) }
	}

	return result
}
