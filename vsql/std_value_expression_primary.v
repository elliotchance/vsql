// ISO/IEC 9075-2:2016(E), 6.3, <value expression primary>

module vsql

// Format
//~
//~ <value expression primary> /* Expr */ ::=
//~     <parenthesized value expression>
//~   | <nonparenthesized value expression primary>
//~
//~ <parenthesized value expression> /* Expr */ ::=
//~     <left paren> <value expression> <right paren>   -> expr
//~
//~ <nonparenthesized value expression primary> /* Expr */ ::=
//~     <unsigned value specification>
//~   | <column reference>               -> identifier_to_expr
//~   | <set function specification>
//~   | <routine invocation>
//~   | <case expression>
//~   | <cast specification>
//~   | <next value expression>

fn parse_expr(e Expr) !Expr {
	return e
}

fn parse_identifier_to_expr(name Identifier) !Expr {
	return name
}
