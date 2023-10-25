// ISO/IEC 9075-2:2016(E), 8.8, <null predicate>

module vsql

// Format
//~
//~ <null predicate> /* Expr */ ::=
//~     <row value predicand> <null predicate part 2>   -> null_predicate
//~
//~ <null predicate part 2> /* bool */ ::=
//~     IS NULL       -> yes
//~   | IS NOT NULL   -> no

fn parse_null_predicate(expr Expr, is_null bool) !Expr {
	return NullExpr{expr, !is_null}
}
