module vsql

import math.big
import math

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
//~ <signed numeric literal> /* Value */ ::=
//~     <unsigned numeric literal>
//~   | <sign> <unsigned numeric literal>   -> signed_numeric_literal_2
//~
//~ <unsigned numeric literal> /* Value */ ::=
//~     <exact numeric literal>
//~   | <approximate numeric literal>
//~
//~ <exact numeric literal> /* Value */ ::=
//~     <unsigned integer>                               -> exact_numeric_literal_1
//~   | <unsigned integer> <period>                      -> exact_numeric_literal_2
//~   | <unsigned integer> <period> <unsigned integer>   -> exact_numeric_literal_3
//~   | <period> <unsigned integer>                      -> exact_numeric_literal_4
//~
//~ <sign> /* string */ ::=
//~     <plus sign>
//~   | <minus sign>
//~
//~ <approximate numeric literal> /* Value */ ::=
//~     <mantissa> E <exponent>   -> approximate_numeric_literal
//~
//~ <mantissa> /* Value */ ::=
//~   <exact numeric literal>
//~
//~ <exponent> /* Value */ ::=
//~   <signed integer>
//~
//~ <signed integer> /* Value */ ::=
//~     <unsigned integer>          -> signed_integer_1
//~   | <sign> <unsigned integer>   -> signed_integer_2
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

fn parse_exact_numeric_literal_1(x string) !Value {
	return numeric_literal(x)
}

fn parse_exact_numeric_literal_2(a string) !Value {
	return numeric_literal('${a}.')
}

fn parse_exact_numeric_literal_3(a string, b string) !Value {
	return numeric_literal('${a}.${b}')
}

fn parse_exact_numeric_literal_4(a string) !Value {
	return numeric_literal('0.${a}')
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

fn parse_signed_numeric_literal_2(sign string, v Value) !Value {
	return numeric_literal(sign + v.str())
}

fn parse_signed_integer_1(v string) !Value {
	return new_numeric_value(v)
}

fn parse_signed_integer_2(sign string, v string) !Value {
	if sign == '-' {
		return new_numeric_value('-' + v)
	}

	return new_numeric_value(v)
}

fn parse_approximate_numeric_literal(mantissa Value, exponent Value) !Value {
	return new_double_precision_value(mantissa.as_f64()! * math.pow(10, exponent.as_f64()!))
}
