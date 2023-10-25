// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>

module vsql

// Format
//~
//~ <numeric value function> /* Expr */ ::=
//~     <position expression>
//~   | <length expression>
//~   | <absolute value expression>
//~   | <modulus expression>
//~   | <trigonometric function>
//~   | <common logarithm>
//~   | <natural logarithm>
//~   | <exponential function>
//~   | <power function>
//~   | <square root>
//~   | <floor function>
//~   | <ceiling function>
//~
//~ <position expression> /* Expr */ ::=
//~     <character position expression>
//~
//~ <character position expression> /* Expr */ ::=
//~     POSITION <left paren> <character value expression 1> IN
//~     <character value expression 2> <right paren>              -> position
//~
//~ <character value expression 1> /* Expr */ ::=
//~     <character value expression>
//~
//~ <character value expression 2> /* Expr */ ::=
//~     <character value expression>
//~
//~ <length expression> /* Expr */ ::=
//~     <char length expression>
//~   | <octet length expression>
//~
//~ <char length expression> /* Expr */ ::=
//~     CHAR_LENGTH
//~     <left paren> <character value expression> <right paren>   -> char_length
//~   | CHARACTER_LENGTH
//~     <left paren> <character value expression> <right paren>   -> char_length
//~
//~ <octet length expression> /* Expr */ ::=
//~     OCTET_LENGTH
//~     <left paren> <string value expression> <right paren>   -> octet_length
//~
//~ <absolute value expression> /* Expr */ ::=
//~     ABS <left paren> <numeric value expression> <right paren>   -> abs
//~
//~ <modulus expression> /* Expr */ ::=
//~     MOD <left paren> <numeric value expression dividend> <comma>
//~     <numeric value expression divisor> <right paren>               -> mod
//~
//~ <numeric value expression dividend> /* Expr */ ::=
//~     <numeric value expression>
//~
//~ <numeric value expression divisor> /* Expr */ ::=
//~     <numeric value expression>
//~
//~ <trigonometric function> /* Expr */ ::=
//~     <trigonometric function name>
//~     <left paren> <numeric value expression>
//~     <right paren>                             -> trig_func
//~
//~ <trigonometric function name> /* string */ ::=
//~     SIN
//~   | COS
//~   | TAN
//~   | SINH
//~   | COSH
//~   | TANH
//~   | ASIN
//~   | ACOS
//~   | ATAN
//~
//~ <common logarithm> /* Expr */ ::=
//~     LOG10 <left paren> <numeric value expression> <right paren>   -> log10
//~
//~ <natural logarithm> /* Expr */ ::=
//~     LN <left paren> <numeric value expression> <right paren>   -> ln
//~
//~ <exponential function> /* Expr */ ::=
//~     EXP <left paren> <numeric value expression> <right paren>   -> exp
//~
//~ <power function> /* Expr */ ::=
//~     POWER <left paren> <numeric value expression base> <comma>
//~     <numeric value expression exponent> <right paren>            -> power
//~
//~ <numeric value expression base> /* Expr */ ::=
//~     <numeric value expression>
//~
//~ <numeric value expression exponent> /* Expr */ ::=
//~     <numeric value expression>
//~
//~ <square root> /* Expr */ ::=
//~     SQRT <left paren> <numeric value expression> <right paren>   -> sqrt
//~
//~ <floor function> /* Expr */ ::=
//~     FLOOR <left paren> <numeric value expression> <right paren>   -> floor
//~
//~ <ceiling function> /* Expr */ ::=
//~     CEIL <left paren> <numeric value expression> <right paren>      -> ceiling
//~   | CEILING <left paren> <numeric value expression> <right paren>   -> ceiling

fn parse_position(expr1 Expr, expr2 Expr) !Expr {
	return CallExpr{'POSITION', [expr1, expr2]}
}

fn parse_char_length(e Expr) !Expr {
	return CallExpr{'CHAR_LENGTH', [e]}
}

fn parse_octet_length(e Expr) !Expr {
	return CallExpr{'OCTET_LENGTH', [e]}
}

fn parse_abs(expr Expr) !Expr {
	return CallExpr{'ABS', [expr]}
}

fn parse_mod(a Expr, b Expr) !Expr {
	return CallExpr{'MOD', [a, b]}
}

fn parse_trig_func(function_name string, expr Expr) !Expr {
	return CallExpr{function_name, [expr]}
}

fn parse_sqrt(expr Expr) !Expr {
	return CallExpr{'SQRT', [expr]}
}

fn parse_ln(expr Expr) !Expr {
	return CallExpr{'LN', [expr]}
}

fn parse_floor(expr Expr) !Expr {
	return CallExpr{'FLOOR', [expr]}
}

fn parse_ceiling(expr Expr) !Expr {
	return CallExpr{'CEILING', [expr]}
}

fn parse_log10(expr Expr) !Expr {
	return CallExpr{'LOG10', [expr]}
}

fn parse_exp(expr Expr) !Expr {
	return CallExpr{'EXP', [expr]}
}

fn parse_power(a Expr, b Expr) !Expr {
	return CallExpr{'POWER', [a, b]}
}
