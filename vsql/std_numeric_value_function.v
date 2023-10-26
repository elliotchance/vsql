// ISO/IEC 9075-2:2016(E), 6.30, <numeric value function>

module vsql

// Format
//~
//~ <numeric value function> /* RoutineInvocation */ ::=
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
//~ <position expression> /* RoutineInvocation */ ::=
//~     <character position expression>
//~
//~ <character position expression> /* RoutineInvocation */ ::=
//~     POSITION <left paren> <character value expression 1> IN
//~     <character value expression 2> <right paren>              -> position
//~
//~ <character value expression 1> /* CharacterValueExpression */ ::=
//~     <character value expression>
//~
//~ <character value expression 2> /* CharacterValueExpression */ ::=
//~     <character value expression>
//~
//~ <length expression> /* RoutineInvocation */ ::=
//~     <char length expression>
//~   | <octet length expression>
//~
//~ <char length expression> /* RoutineInvocation */ ::=
//~     CHAR_LENGTH
//~     <left paren> <character value expression> <right paren>   -> char_length
//~   | CHARACTER_LENGTH
//~     <left paren> <character value expression> <right paren>   -> char_length
//~
//~ <octet length expression> /* RoutineInvocation */ ::=
//~     OCTET_LENGTH
//~     <left paren> <string value expression> <right paren>   -> octet_length
//~
//~ <absolute value expression> /* RoutineInvocation */ ::=
//~     ABS <left paren> <numeric value expression> <right paren>   -> abs
//~
//~ <modulus expression> /* RoutineInvocation */ ::=
//~     MOD <left paren> <numeric value expression dividend> <comma>
//~     <numeric value expression divisor> <right paren>               -> mod
//~
//~ <numeric value expression dividend> /* NumericValueExpression */ ::=
//~     <numeric value expression>
//~
//~ <numeric value expression divisor> /* NumericValueExpression */ ::=
//~     <numeric value expression>
//~
//~ <trigonometric function> /* RoutineInvocation */ ::=
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
//~ <common logarithm> /* RoutineInvocation */ ::=
//~     LOG10 <left paren> <numeric value expression> <right paren>   -> log10
//~
//~ <natural logarithm> /* RoutineInvocation */ ::=
//~     LN <left paren> <numeric value expression> <right paren>   -> ln
//~
//~ <exponential function> /* RoutineInvocation */ ::=
//~     EXP <left paren> <numeric value expression> <right paren>   -> exp
//~
//~ <power function> /* RoutineInvocation */ ::=
//~     POWER <left paren> <numeric value expression base> <comma>
//~     <numeric value expression exponent> <right paren>            -> power
//~
//~ <numeric value expression base> /* NumericValueExpression */ ::=
//~     <numeric value expression>
//~
//~ <numeric value expression exponent> /* NumericValueExpression */ ::=
//~     <numeric value expression>
//~
//~ <square root> /* RoutineInvocation */ ::=
//~     SQRT <left paren> <numeric value expression> <right paren>   -> sqrt
//~
//~ <floor function> /* RoutineInvocation */ ::=
//~     FLOOR <left paren> <numeric value expression> <right paren>   -> floor
//~
//~ <ceiling function> /* RoutineInvocation */ ::=
//~     CEIL <left paren> <numeric value expression> <right paren>      -> ceiling
//~   | CEILING <left paren> <numeric value expression> <right paren>   -> ceiling

fn parse_position(expr1 CharacterValueExpression, expr2 CharacterValueExpression) !RoutineInvocation {
	return RoutineInvocation{'POSITION', [
		ValueExpression(CommonValueExpression(expr1)),
		ValueExpression(CommonValueExpression(expr2)),
	]}
}

fn parse_char_length(e CharacterValueExpression) !RoutineInvocation {
	return RoutineInvocation{'CHAR_LENGTH', [
		ValueExpression(CommonValueExpression(e)),
	]}
}

fn parse_octet_length(e CharacterValueExpression) !RoutineInvocation {
	return RoutineInvocation{'OCTET_LENGTH', [
		ValueExpression(CommonValueExpression(e)),
	]}
}

fn parse_abs(expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'ABS', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_mod(a NumericValueExpression, b NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'MOD', [ValueExpression(CommonValueExpression(a)),
		ValueExpression(CommonValueExpression(b))]}
}

fn parse_trig_func(function_name string, expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{function_name, [
		ValueExpression(CommonValueExpression(expr)),
	]}
}

fn parse_sqrt(expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'SQRT', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_ln(expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'LN', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_floor(expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'FLOOR', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_ceiling(expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'CEILING', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_log10(expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'LOG10', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_exp(expr NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'EXP', [ValueExpression(CommonValueExpression(expr))]}
}

fn parse_power(a NumericValueExpression, b NumericValueExpression) !RoutineInvocation {
	return RoutineInvocation{'POWER', [ValueExpression(CommonValueExpression(a)),
		ValueExpression(CommonValueExpression(b))]}
}
