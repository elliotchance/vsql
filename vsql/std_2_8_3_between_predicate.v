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
	c.check_time_zone_comparison(compiled_expr.typ, compiled_left.typ)!
	c.check_time_zone_comparison(compiled_expr.typ, compiled_right.typ)!

	return CompileResult{
		run:          fn [e, compiled_expr, compiled_left, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := compiled_expr.run(mut conn, data, params)!
			left := compiled_left.run(mut conn, data, params)!
			right := compiled_right.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2016(E), 8.3, <between predicate>, Syntax Rules 4 and 6:
			//
			//   X BETWEEN ASYMMETRIC Y AND Z is X >= Y AND X <= Z
			//   X BETWEEN SYMMETRIC Y AND Z is
			//     (X BETWEEN ASYMMETRIC Y AND Z) OR (X BETWEEN ASYMMETRIC Z AND Y)
			//
			// With three-valued logic a NULL bound doesn't always make the result
			// UNKNOWN. For example, 5 BETWEEN NULL AND 2 is FALSE.
			mut result := between_asymmetric(compare(conn, expr, left)!, compare(conn,
				expr, right)!)
			if e.symmetric {
				result = truth_or(result, between_asymmetric(compare(conn, expr, right)!,
					compare(conn, expr, left)!))
			}

			if e.not {
				result = truth_not(result)
			}

			return match result {
				.is_true { new_boolean_value(true) }
				.is_false { new_boolean_value(false) }
				.is_unknown { new_unknown_value() }
			}
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_expr.contains_agg || compiled_left.contains_agg
			|| compiled_right.contains_agg
	}
}

// Truth is a value of three-valued logic.
enum Truth {
	is_false
	is_true
	is_unknown
}

// between_asymmetric is "X >= Y AND X <= Z", given the comparisons of X with Y
// (lower) and X with Z (upper).
fn between_asymmetric(lower CompareResult, upper CompareResult) Truth {
	at_least := match lower {
		.is_unknown { Truth.is_unknown }
		.is_less { Truth.is_false }
		else { Truth.is_true }
	}
	at_most := match upper {
		.is_unknown { Truth.is_unknown }
		.is_greater { Truth.is_false }
		else { Truth.is_true }
	}

	return truth_and(at_least, at_most)
}

fn truth_and(a Truth, b Truth) Truth {
	if a == .is_false || b == .is_false {
		return .is_false
	}

	if a == .is_unknown || b == .is_unknown {
		return .is_unknown
	}

	return .is_true
}

fn truth_or(a Truth, b Truth) Truth {
	if a == .is_true || b == .is_true {
		return .is_true
	}

	if a == .is_unknown || b == .is_unknown {
		return .is_unknown
	}

	return .is_false
}

fn truth_not(a Truth) Truth {
	return match a {
		.is_true { .is_false }
		.is_false { .is_true }
		.is_unknown { .is_unknown }
	}
}
