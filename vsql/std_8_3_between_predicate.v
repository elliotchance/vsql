module vsql

// ISO/IEC 9075-2:2016(E), 8.3, <between predicate>
//
// # Function
//
// Specify a range comparison.
//
// # Format
//~
//~ <between predicate> /* BetweenPredicate */ ::=
//~     <row value predicand> <between predicate part 2>   -> between
//~
//~ <between predicate part 2> /* BetweenPredicate */ ::=
//~     <between predicate part 1>
//~     <row value predicand> AND <row value predicand>   -> between_1
//~   | <between predicate part 1> <is symmetric>
//~     <row value predicand> AND <row value predicand>   -> between_2
//~
//~ <between predicate part 1> /* bool */ ::=
//~     BETWEEN       -> yes
//~   | NOT BETWEEN   -> no
//
// These are non-standard, just to simplify standard rules:
//~
//~ <is symmetric> /* bool */ ::=
//~     SYMMETRIC    -> yes
//~   | ASYMMETRIC   -> no

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

fn parse_between(expr RowValueConstructorPredicand, between BetweenPredicate) !BetweenPredicate {
	return BetweenPredicate{
		not:       between.not
		symmetric: between.symmetric
		expr:      expr
		left:      between.left
		right:     between.right
	}
}

fn parse_between_1(is_true bool, left RowValueConstructorPredicand, right RowValueConstructorPredicand) !BetweenPredicate {
	// false between ASYMMETRIC by default.
	return parse_between_2(is_true, false, left, right)
}

fn parse_between_2(is_true bool, symmetric bool, left RowValueConstructorPredicand, right RowValueConstructorPredicand) !BetweenPredicate {
	return BetweenPredicate{
		not:       !is_true
		symmetric: symmetric
		left:      left
		right:     right
	}
}
