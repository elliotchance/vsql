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

// plan_compared_subquery plans a subquery whose rows are compared with expr,
// which is a row or a single value (see compile_fields).
fn plan_compared_subquery(mut c Compiler, subquery Subquery, expr []CompileResult) !SubqueryPlan {
	plan := subquery.plan_row(mut c, expr.len)!
	c.check_row_comparison(expr.map(it.typ), plan.plan.columns().map(it.typ))!

	return plan
}

fn (e QuantifiedComparisonPredicate) compile(mut c Compiler) !CompileResult {
	compiled_expr := e.expr.compile_fields(mut c)!
	plan := plan_compared_subquery(mut c, e.subquery, compiled_expr)!

	return CompileResult{
		run:          fn [e, compiled_expr, plan] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := run_fields(mut conn, compiled_expr, data, params)!
			rows := subquery_rows(mut conn, plan, data)!

			return quantified_comparison(conn, expr, e.op, e.all, rows)!.value()
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_expr.any(it.contains_agg) || plan.contains_agg
	}
}

// quantified_comparison compares expr with each of the rows (which are single
// values unless expr is a row). Every row is compared (rather than stopping at
// the first result that decides it) so that an incomparable value is always an
// error, wherever it is.
//
// ISO/IEC 9075-2:2016(E), 8.9, <quantified comparison predicate>, General
// Rules, 2
fn quantified_comparison(conn &Connection, expr []Value, op ComparisonOperator, all bool, rows [][]Value) !Truth {
	// a) and d): An empty table is TRUE for ALL and FALSE for SOME.
	mut result := if all { Truth.is_true } else { Truth.is_false }
	for row in rows {
		truth := op.row_truth(compare_rows(conn, expr, row)!)

		// b) ALL is FALSE if any comparison is FALSE, and c) SOME is TRUE if any
		// comparison is TRUE. e) Otherwise, it's UNKNOWN.
		result = if all { truth_and(result, truth) } else { truth_or(result, truth) }
	}

	return result
}
