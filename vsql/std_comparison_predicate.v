// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>

module vsql

// Format
//~
//~ <comparison predicate> /* ComparisonPredicate */ ::=
//~     <row value predicand> <comparison predicate part 2>   -> comparison
//~
//~ <comparison predicate part 2> /* ComparisonPredicatePart2 */ ::=
//~     <comp op> <row value predicand>   -> comparison_part
//~
//~ <comp op> /* string */ ::=
//~     <equals operator>
//~   | <not equals operator>
//~   | <less than operator>
//~   | <greater than operator>
//~   | <less than or equals operator>
//~   | <greater than or equals operator>

struct ComparisonPredicate {
	left  Expr
	op    string
	right Expr
}

fn (e ComparisonPredicate) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} ${e.op} ${e.right.pstr(params)}'
}

fn (e ComparisonPredicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	mut left := eval_as_value(mut conn, data, e.left, params)!
	mut right := eval_as_value(mut conn, data, e.right, params)!

	cmp := compare(left, right)!
	if cmp == .is_unknown {
		return new_unknown_value()
	}

	return new_boolean_value(match e.op {
		'=' {
			cmp == .is_equal
		}
		'<>' {
			cmp != .is_equal
		}
		'>' {
			cmp == .is_greater
		}
		'<' {
			cmp == .is_less
		}
		'>=' {
			cmp == .is_greater || cmp == .is_equal
		}
		'<=' {
			cmp == .is_less || cmp == .is_equal
		}
		else {
			// This should not be possible, but it's to satisfy the required else.
			panic('invalid binary operator: ${e.op}')
		}
	})
}

fn (e ComparisonPredicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if expr_is_agg(conn, e.left, row, params)! || expr_is_agg(conn, e.right, row, params)! {
		return nested_agg_unsupported(Predicate(e))
	}

	return false
}

fn (e ComparisonPredicate) resolve_identifiers(conn &Connection, tables map[string]Table) !Expr {
	return Predicate(ComparisonPredicate{resolve_identifiers(conn, e.left, tables)!, e.op, resolve_identifiers(conn,
		e.right, tables)!})
}

struct ComparisonPredicatePart2 {
	op   string
	expr Expr
}

fn parse_comparison_part(op string, expr Expr) !ComparisonPredicatePart2 {
	return ComparisonPredicatePart2{op, expr}
}

fn parse_comparison(expr Expr, comp ComparisonPredicatePart2) !ComparisonPredicate {
	return ComparisonPredicate{expr, comp.op, comp.expr}
}
