module vsql

import math.big

// ISO/IEC 9075-2:2016(E), 5.3, <literal>
//
// # Function
//
// Specify a non-null value.
//
// # Format
//~
//~ <literal> /* Value */ ::=
//~     <signed numeric literal>
//~   | <general literal>
//~
//~ <unsigned literal> /* Value */ ::=
//~     <unsigned numeric literal>   -> signed_numeric_literal_1
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
//~ <signed numeric literal> /* Value */ ::=
//~     <unsigned numeric literal>          -> signed_numeric_literal_1
//~   | <sign> <unsigned numeric literal>   -> signed_numeric_literal_2
//~
//~ <unsigned numeric literal> /* string */ ::=
//~     <exact numeric literal>
//~
//~ <exact numeric literal> /* string */ ::=
//~     <unsigned integer>                               -> exact_numeric_literal_1
//~   | <unsigned integer> <period>                      -> exact_numeric_literal_2
//~   | <unsigned integer> <period> <unsigned integer>   -> exact_numeric_literal_3
//~   | <period> <unsigned integer>                      -> exact_numeric_literal_4
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

fn parse_exact_numeric_literal_1(x string) !string {
	return x
}

fn parse_exact_numeric_literal_2(a string) !string {
	return '${a}.'
}

fn parse_exact_numeric_literal_3(a string, b string) !string {
	return '${a}.${b}'
}

fn parse_exact_numeric_literal_4(a string) !string {
	return '0.${a}'
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

fn numeric_literal(x string) !Value {
	// Any number that contains a decimal (even if its a whole number) must be
	// treated as a NUMERIC.
	if x.contains('.') {
		// The trim handles cases of "123." which should be treated as "123".
		return new_numeric_value(x.trim_right('.'))
	}

	// Otherwise, we know this is an int but we have to choose the smallest type.
	//
	// Note: There is an edge case where the negative sign may be consumed as part
	// of <factor> rather than <signed numeric literal>. See parse_factor_2() for
	// those edge cases.
	n := big.integer_from_string(x)!

	if n >= big.integer_from_i64(-32768) && n <= big.integer_from_i64(32767) {
		return new_smallint_value(i16(x.i64()))
	}

	if n >= big.integer_from_i64(-2147483648) && n <= big.integer_from_i64(2147483647) {
		return new_integer_value(int(x.i64()))
	}

	if n >= big.integer_from_i64(-9223372036854775808)
		&& n <= big.integer_from_i64(9223372036854775807) {
		return new_bigint_value(x.i64())
	}

	return new_numeric_value(x)
}

fn parse_signed_numeric_literal_1(v string) !Value {
	return numeric_literal(v)
}

fn parse_signed_numeric_literal_2(sign string, v string) !Value {
	return numeric_literal(sign + v)
}
