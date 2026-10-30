module vsql

// ISO/IEC 9075-2:2016(E), 8.10, <exists predicate>
//
// Specify a test for a non-empty set.

// ExistsPredicate is "EXISTS (SELECT ...)". It's never UNKNOWN.
struct ExistsPredicate {
	subquery Subquery
}

fn (e ExistsPredicate) pstr(params map[string]Value) string {
	return 'EXISTS ${e.subquery.pstr(params)}'
}

fn (e ExistsPredicate) compile(mut c Compiler) !CompileResult {
	// Any number of columns is allowed, which is Feature T501, "Enhanced EXISTS
	// predicate" (ISO/IEC 9075-2:2016(E), 8.10, <exists predicate>, Conformance
	// Rules, 1).
	plan := e.subquery.plan(mut c)!

	return CompileResult{
		run:          fn [plan] (mut conn Connection, data Row, params map[string]Value) !Value {
			// ISO/IEC 9075-2:2016(E), 8.10, <exists predicate>, General Rules, 2
			return new_boolean_value(run_subquery(mut conn, plan, data)!.len > 0)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: plan.contains_agg
	}
}
