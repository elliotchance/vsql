// ISO/IEC 9075-2:2016(E), 6.32, <string value function>

module vsql

// Format
//~
//~ <string value function> /* Expr */ ::=
//~     <character value function>
//~
//~ <character value function> /* Expr */ ::=
//~     <character substring function>
//~   | <fold>
//~   | <trim function>
//~
//~ <character substring function> /* Expr */ ::=
//~     SUBSTRING <left paren> <character value expression>
//~     FROM <start position> <right paren>                   -> substring1
//~   | SUBSTRING <left paren> <character value expression>
//~     FROM <start position>
//~     FOR <string length> <right paren>                     -> substring2
//~   | SUBSTRING <left paren> <character value expression>
//~     FROM <start position>
//~     USING <char length units> <right paren>               -> substring3
//~   | SUBSTRING <left paren> <character value expression>
//~     FROM <start position>
//~     FOR <string length>
//~     USING <char length units> <right paren>               -> substring4
//~
//~ <fold> /* Expr */ ::=
//~     UPPER <left paren> <character value expression> <right paren>   -> upper
//~   | LOWER <left paren> <character value expression> <right paren>   -> lower
//~
//~ <trim function> /* Expr */ ::=
//~   TRIM <left paren> <trim operands> <right paren>   -> trim
//~
//~ <trim operands> /* Expr */ ::=
//~     <trim source>                                              -> trim1
//~   | FROM <trim source>                                         -> trim1
//~   | <trim specification> FROM <trim source>                    -> trim2
//~   | <trim character> FROM <trim source>                        -> trim3
//~   | <trim specification> <trim character> FROM <trim source>   -> trim4
//~
//~ <trim source> /* Expr */ ::=
//~     <character value expression>
//~
//~ <trim specification> /* string */ ::=
//~     LEADING
//~   | TRAILING
//~   | BOTH
//~
//~ <trim character> /* Expr */ ::=
//~     <character value expression>
//~
//~ <start position> /* Expr */ ::=
//~     <numeric value expression>
//~
//~ <string length> /* Expr */ ::=
//~     <numeric value expression>

fn parse_substring1(value Expr, from Expr) !Expr {
	return SubstringExpr{value, from, NoExpr{}, 'CHARACTERS'}
}

fn parse_substring2(value Expr, from Expr, @for Expr) !Expr {
	return SubstringExpr{value, from, @for, 'CHARACTERS'}
}

fn parse_substring3(value Expr, from Expr, using string) !Expr {
	return SubstringExpr{value, from, NoExpr{}, using}
}

fn parse_substring4(value Expr, from Expr, @for Expr, using string) !Expr {
	return SubstringExpr{value, from, @for, using}
}

fn parse_upper(expr Expr) !Expr {
	return CallExpr{'UPPER', [expr]}
}

fn parse_lower(expr Expr) !Expr {
	return CallExpr{'LOWER', [expr]}
}

fn parse_trim1(source Expr) !Expr {
	return TrimExpr{'BOTH', new_varchar_value(' '), source}
}

fn parse_trim2(specification string, source Expr) !Expr {
	return TrimExpr{specification, new_varchar_value(' '), source}
}

fn parse_trim3(character Expr, source Expr) !Expr {
	return TrimExpr{'BOTH', character, source}
}

fn parse_trim4(specification string, character Expr, source Expr) !Expr {
	return TrimExpr{specification, character, source}
}

fn parse_trim(e Expr) !Expr {
	return e
}
