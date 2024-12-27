module vsql

import math.big

// ISO/IEC 9075-2:2016(E), 5.3, <literal>
//
// Specify a non-null value.

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
