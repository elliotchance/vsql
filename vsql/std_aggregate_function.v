// ISO/IEC 9075-2:2016(E), 10.9, <aggregate function>

module vsql

// Format
//~
//~ <aggregate function> /* Expr */ ::=
//~     COUNT <left paren> <asterisk> <right paren>   -> count_all
//~   | <general set function>
//~
//~ <general set function> /* Expr */ ::=
//~     <set function type> <left paren>
//~     <value expression> <right paren>   -> general_set_function
//~
//~ <set function type> /* string */ ::=
//~     <computational operation>
//~
//~ <computational operation> /* string */ ::=
//~     AVG
//~   | MAX
//~   | MIN
//~   | SUM
//~   | COUNT

fn parse_count_all(asterisk string) !Expr {
	return CountAllExpr{}
}

fn parse_general_set_function(name string, expr Expr) !Expr {
	return CallExpr{name, [expr]}
}
