// ISO/IEC 9075-2:2016(E), 8.3, <between predicate>

module vsql

// Format
//~
//~ <between predicate> /* Expr */ ::=
//~     <row value predicand> <between predicate part 2>   -> between
//~
//~ <between predicate part 2> /* BetweenExpr */ ::=
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

fn parse_between(expr Expr, between BetweenExpr) !Expr {
	return BetweenExpr{
		not: between.not
		symmetric: between.symmetric
		expr: expr
		left: between.left
		right: between.right
	}
}

fn parse_between1(is_true bool, left Expr, right Expr) !BetweenExpr {
	// false between ASYMMETRIC by default.
	return parse_between2(is_true, false, left, right)
}

fn parse_between2(is_true bool, symmetric bool, left Expr, right Expr) !BetweenExpr {
	return BetweenExpr{
		not: !is_true
		symmetric: symmetric
		left: left
		right: right
	}
}
