module vsql

// ISO/IEC 9075-2:2016(E), 8.3, <between predicate>
//
// Specify a range comparison.

struct BetweenPredicate {
	not       bool
	symmetric bool
	expr      RowValueConstructorPredicand
	left      RowValueConstructorPredicand
	right     RowValueConstructorPredicand
}

fn (e BetweenPredicate) pstr(params map[string]Value) string {
	return '${e.expr.pstr(params)} ' + if e.not {
		'NOT '
	} else {
		''
	} + 'BETWEEN ' + if e.symmetric {
		'SYMMETRIC '
	} else {
		''
	} + '${e.left.pstr(params)} AND ${e.right.pstr(params)}'
}

fn (e BetweenPredicate) compile(mut c Compiler) !CompileResult {
	compiled_expr := e.expr.compile(mut c)!
	compiled_left := e.left.compile(mut c)!
	compiled_right := e.right.compile(mut c)!

	return CompileResult{
		run:          fn [e, compiled_expr, compiled_left, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := compiled_expr.run(mut conn, data, params)!
			mut left := compiled_left.run(mut conn, data, params)!
			mut right := compiled_right.run(mut conn, data, params)!

			// SYMMETRIC operands might need to be swapped.
			cmp := compare(left, right)!
			if e.symmetric && cmp == .is_greater {
				left, right = right, left
			}

			lower := compare(expr, left)!
			upper := compare(expr, right)!

			if lower == .is_unknown || upper == .is_unknown {
				return new_unknown_value()
			}

			mut result := (lower == .is_greater || lower == .is_equal)
				&& (upper == .is_less || upper == .is_equal)

			if e.not {
				result = !result
			}

			return new_boolean_value(result)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_expr.contains_agg || compiled_left.contains_agg
			|| compiled_left.contains_agg
	}
}
