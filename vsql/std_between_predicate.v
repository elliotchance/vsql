// ISO/IEC 9075-2:2016(E), 8.3, <between predicate>

module vsql

// Format
//~
//~ <between predicate> /* BetweenPredicate */ ::=
//~     <row value predicand> <between predicate part 2>   -> between
//~
//~ <between predicate part 2> /* BetweenPredicate */ ::=
//~     <between predicate part 1>
//~     <row value predicand> AND <row value predicand>   -> between1
//~   | <between predicate part 1> <is symmetric>
//~     <row value predicand> AND <row value predicand>   -> between2
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
	expr      Expr
	left      Expr
	right     Expr
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

fn (e BetweenPredicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	expr := eval_as_value(mut conn, data, e.expr, params)!
	mut left := eval_as_value(mut conn, data, e.left, params)!
	mut right := eval_as_value(mut conn, data, e.right, params)!

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

fn (e BetweenPredicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if expr_is_agg(conn, e.left, row, params)! || expr_is_agg(conn, e.right, row, params)! {
		return nested_agg_unsupported(Predicate(e))
	}

	return false
}

fn (e BetweenPredicate) resolve_identifiers(conn &Connection, tables map[string]Table) !Expr {
	return Predicate(BetweenPredicate{e.not, e.symmetric, resolve_identifiers(conn, e.expr,
		tables)!, resolve_identifiers(conn, e.left, tables)!, resolve_identifiers(conn,
		e.right, tables)!})
}

fn parse_between(expr Expr, between BetweenPredicate) !BetweenPredicate {
	return BetweenPredicate{
		not: between.not
		symmetric: between.symmetric
		expr: expr
		left: between.left
		right: between.right
	}
}

fn parse_between1(is_true bool, left Expr, right Expr) !BetweenPredicate {
	// false between ASYMMETRIC by default.
	return parse_between2(is_true, false, left, right)
}

fn parse_between2(is_true bool, symmetric bool, left Expr, right Expr) !BetweenPredicate {
	return BetweenPredicate{
		not: !is_true
		symmetric: symmetric
		left: left
		right: right
	}
}
