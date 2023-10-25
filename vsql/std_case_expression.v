// ISO/IEC 9075-2:2016(E), 6.12, <case expression>

module vsql

// Format
//~
//~ <case expression> /* Expr */ ::=
//~     <case abbreviation>
//~
//~ <case abbreviation> /* Expr */ ::=
//~     NULLIF <left paren> <value expression>
//~     <comma> <value expression> <right paren>                      -> nullif
//~   | COALESCE <left paren> <value expression list> <right paren>   -> coalesce
//
// These are non-standard, just to simplify standard rules:
//~
//~ <value expression list> /* []Expr */ ::=
//~     <value expression>                                   -> expr_to_list
//~   | <value expression list> <comma> <value expression>   -> append_exprs1

fn parse_nullif(a Expr, b Expr) !Expr {
	return NullIfExpr{a, b}
}

fn parse_coalesce(exprs []Expr) !Expr {
	return CoalesceExpr{exprs}
}
