module vsql

// ISO/IEC 9075-2:2023(E), 8.3, <between predicate>
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

// compile_between compiles the predicate. "X BETWEEN Z AND Y" is transformed into
// "X >= Z AND X <= Y", so if it's retrospective (see Compiler.retrospective) Y can
// be the current date or timestamp. It can't with NOT, and SYMMETRIC also has
// "X >= Y". X, Y and Z can also be rows of the same degree.
//
// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, Syntax Rules, 7.c.iv
fn (e BetweenPredicate) compile_between(mut c Compiler, retrospective bool) !CompileResult {
	untyped_expr := e.expr.compile_fields(mut c)!
	untyped_left := e.left.compile_fields(mut c)!
	untyped_right := if retrospective && !e.not && !e.symmetric
		&& e.right !is ExplicitRowValueConstructor {
		[c.compile_retrospective(e.right)!]
	} else {
		e.right.compile_fields(mut c)!
	}

	// ISO/IEC 9075-2:2023(E), 20.7, <prepare statement>, General Rules, 5.a.xxi
	typed := c.with_row_types([untyped_expr, untyped_left, untyped_right])
	compiled_expr, compiled_left, compiled_right := typed[0], typed[1], typed[2]
	c.check_row_comparison(compiled_expr.map(it.typ), compiled_left.map(it.typ), null_parameters(compiled_expr,
		compiled_left))!
	c.check_row_comparison(compiled_expr.map(it.typ), compiled_right.map(it.typ), null_parameters(compiled_expr,
		compiled_right))!

	return CompileResult{
		run:          fn [e, compiled_expr, compiled_left, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := run_fields(mut conn, compiled_expr, data, params)!
			left := run_fields(mut conn, compiled_left, data, params)!
			right := run_fields(mut conn, compiled_right, data, params)!

			// ISO/IEC 9075-2:2023(E), 8.3, <between predicate>, Syntax Rules, 4
			// and 6 (ASYMMETRIC is implicit, Syntax Rules, 1):
			//
			//   X BETWEEN ASYMMETRIC Y AND Z is X >= Y AND X <= Z
			//   X BETWEEN SYMMETRIC Y AND Z is
			//     (X BETWEEN ASYMMETRIC Y AND Z) OR (X BETWEEN ASYMMETRIC Z AND Y)
			//
			// With three-valued logic a NULL bound doesn't always make the result
			// UNKNOWN. For example, 5 BETWEEN NULL AND 2 is FALSE.
			mut result := between_asymmetric(compare_rows(conn, expr, left)!, compare_rows(conn,
				expr, right)!)
			if e.symmetric {
				result = truth_or(result, between_asymmetric(compare_rows(conn, expr,
					right)!, compare_rows(conn, expr, left)!))
			}

			// ISO/IEC 9075-2:2023(E), 8.3, <between predicate>, Syntax Rules, 3
			// and 5: X NOT BETWEEN ... is NOT (X BETWEEN ...).
			if e.not {
				result = truth_not(result)
			}

			return result.value()
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_expr.any(it.contains_agg) || compiled_left.any(it.contains_agg)
			|| compiled_right.any(it.contains_agg)
	}
}

// Truth is a value of three-valued logic. Unknown is the same as the null value
// of BOOLEAN (ISO/IEC 9075-2:2023(E), 4.6.1, Introduction to Boolean types).
enum Truth {
	is_false
	is_true
	is_unknown
}

fn (t Truth) value() Value {
	return match t {
		.is_true { new_boolean_value(true) }
		.is_false { new_boolean_value(false) }
		.is_unknown { new_unknown_value() }
	}
}

// between_asymmetric is "X >= Y AND X <= Z", given the comparisons of X with Y
// (lower) and X with Z (upper).
fn between_asymmetric(lower []CompareResult, upper []CompareResult) Truth {
	at_least := ComparisonOperator.greater_than_or_equal.row_truth(lower)
	at_most := ComparisonOperator.less_than_or_equal.row_truth(upper)

	return truth_and(at_least, at_most)
}

// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, General Rules, 3,
// Table 13, Truth table for the AND boolean operator
fn truth_and(a Truth, b Truth) Truth {
	if a == .is_false || b == .is_false {
		return .is_false
	}

	if a == .is_unknown || b == .is_unknown {
		return .is_unknown
	}

	return .is_true
}

// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, General Rules, 3,
// Table 14, Truth table for the OR boolean operator
fn truth_or(a Truth, b Truth) Truth {
	if a == .is_true || b == .is_true {
		return .is_true
	}

	if a == .is_unknown || b == .is_unknown {
		return .is_unknown
	}

	return .is_false
}

// ISO/IEC 9075-2:2023(E), 6.46, <boolean value expression>, General Rules, 2
fn truth_not(a Truth) Truth {
	return match a {
		.is_true { .is_false }
		.is_false { .is_true }
		.is_unknown { .is_unknown }
	}
}
