// ISO/IEC 9075-2:2016(E), 5.3, <literal>

module vsql

// Format
//~
//~ <literal> /* Expr */ ::=
//~     <signed numeric literal>
//~   | <general literal>          -> value_to_expr
//~
//~ <unsigned literal> /* Value */ ::=
//~     <unsigned numeric literal>
//~   | <general literal>
//~
//~ <general literal> /* Value */ ::=
//~     <character string literal>
//~   | <datetime literal>
//~   | <boolean literal>
//~
//~ <character string literal> /* Value */ ::=
//~     ^string
//~
//~ <signed numeric literal> /* Expr */ ::=
//~     <unsigned numeric literal>          -> value_to_expr
//~   | <sign> <unsigned numeric literal>   -> sign_expr
//~
//~ <unsigned numeric literal> /* Value */ ::=
//~     <exact numeric literal>
//~
//~ <exact numeric literal> /* Value */ ::=
//~     <unsigned integer>                               -> int_value
//~   | <unsigned integer> <period>                      -> int_value
//~   | <unsigned integer> <period> <unsigned integer>   -> exact_numeric_literal1
//~   | <period> <unsigned integer>                      -> exact_numeric_literal2
//~
//~ <sign> /* string */ ::=
//~     <plus sign>
//~   | <minus sign>
//~
//~ <unsigned integer> /* string */ ::=
//~     ^integer
//~
//~ <datetime literal> /* Value */ ::=
//~     <date literal>
//~   | <time literal>
//~   | <timestamp literal>
//~
//~ <date literal> /* Value */ ::=
//~     DATE <date string>   -> date_literal
//~
//~ <time literal> /* Value */ ::=
//~     TIME <time string>   -> time_literal
//~
//~ <timestamp literal> /* Value */ ::=
//~     TIMESTAMP <timestamp string>   -> timestamp_literal
//~
//~ <date string> /* Value */ ::=
//~     ^string
//~
//~ <time string> /* Value */ ::=
//~     ^string
//~
//~ <timestamp string> /* Value */ ::=
//~     ^string
//~
//~ <boolean literal> /* Value */ ::=
//~     TRUE      -> true
//~   | FALSE     -> false
//~   | UNKNOWN   -> unknown

fn parse_int_value(x string) !Value {
	return new_numeric_value(x)
}

fn parse_exact_numeric_literal1(a string, b string) !Value {
	return new_numeric_value('${a}.${b}')
}

fn parse_exact_numeric_literal2(a string) !Value {
	return new_numeric_value('0.${a}')
}

fn parse_date_literal(v Value) !Value {
	return new_date_value(v.string_value())
}

fn parse_time_literal(v Value) !Value {
	return new_time_value(v.string_value())
}

fn parse_timestamp_literal(v Value) !Value {
	return new_timestamp_value(v.string_value())
}

fn parse_value_to_expr(v Value) !Expr {
	return v
}
