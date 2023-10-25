// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>

module vsql

// Format
//~
//~ <similar predicate> /* Expr */ ::=
//~     <row value predicand> <similar predicate part 2>   -> similar_pred
//~
//~ <similar predicate part 2> /* SimilarExpr */ ::=
//~     SIMILAR TO <similar pattern>       -> similar
//~   | NOT SIMILAR TO <similar pattern>   -> not_similar
//~
//~ <similar pattern> /* Expr */ ::=
//~     <character value expression>

fn parse_similar_pred(left Expr, like SimilarExpr) !Expr {
	return SimilarExpr{left, like.right, like.not}
}

fn parse_similar(expr Expr) !SimilarExpr {
	return SimilarExpr{NoExpr{}, expr, false}
}

fn parse_not_similar(expr Expr) !SimilarExpr {
	return SimilarExpr{NoExpr{}, expr, true}
}
