// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>

module vsql

// Format
//~
//~ <like predicate> /* Expr */ ::=
//~     <character like predicate>
//~
//~ <character like predicate> /* Expr */ ::=
//~     <row value predicand> <character like predicate part 2>   -> like_pred
//~
//~ <character like predicate part 2> /* LikeExpr */ ::=
//~     LIKE <character pattern>       -> like
//~   | NOT LIKE <character pattern>   -> not_like
//~
//~ <character pattern> /* Expr */ ::=
//~     <character value expression>

fn parse_like_pred(left Expr, like LikeExpr) !Expr {
	return LikeExpr{left, like.right, like.not}
}

fn parse_like(expr Expr) !LikeExpr {
	return LikeExpr{NoExpr{}, expr, false}
}

fn parse_not_like(expr Expr) !LikeExpr {
	return LikeExpr{NoExpr{}, expr, true}
}
