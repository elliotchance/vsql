module vsql

import math.big

// ISO/IEC 9075-2:2016(E), 5.3, <literal>
//
// Specify a non-null value.

#include <stdlib.h>

fn C.strtod(&char, &&char) f64

// approximate_numeric_literal_value parses an approximate numeric literal (such
// as "1.5e-3") as a whole, rather than multiplying the mantissa by a power of
// 10, so that it's the closest DOUBLE PRECISION to the exact value. strtod is
// used because strconv.atof64 isn't always the closest in every version of V.
fn approximate_numeric_literal_value(x string) !Value {
	return approximate_value(C.strtod(&char(x.str), unsafe { nil }), .is_double_precision)
}

// signed_numeric_literal applies a sign to an unsigned numeric literal, such as
// -1.5 or -1.5e2.
fn signed_numeric_literal(sign string, v Value) !Value {
	if v.typ.typ == .is_double_precision {
		return new_double_precision_value(if sign == '-' { -v.f64_value() } else { v.f64_value() })
	}

	return numeric_literal(sign + v.str())!
}

fn numeric_literal(x string) !Value {
	// There must be an exact numeric type that can hold the literal (Syntax Rule
	// 22), so it can't have more digits than the maximum precision. Leading
	// zeros don't count.
	mut digits := 0
	mut leading := true
	mut has_point := false
	for c in x {
		if c == `.` {
			has_point = true
			leading = false
		} else if c >= `0` && c <= `9` && !(leading && c == `0`) {
			digits++
			leading = false
		}
	}
	if digits > max_numeric_precision {
		return sqlstate_42601('numeric literal has more than ${max_numeric_precision} digits')
	}

	// Any number that contains a decimal (even if its a whole number) must be
	// treated as a NUMERIC.
	if has_point {
		// The trim handles cases of "123." which should be treated as "123".
		return new_numeric_value(x.trim_right('.'))
	}

	// Otherwise, we know this is an int but we have to choose the smallest type.
	//
	// Note: There is an edge case where the negative sign may be consumed as part
	// of <factor> rather than <signed numeric literal>. See parse_factor_2() for
	// those edge cases.
	//
	// Any integer with up to 18 digits fits in an i64, so only a longer one
	// needs a big.Integer to find out if it's a BIGINT.
	if digits <= 18 {
		v := x.i64()
		if v >= min_i16 && v <= max_i16 {
			return new_smallint_value(i16(v))
		}

		if v >= min_i32 && v <= max_i32 {
			return new_integer_value(int(v))
		}

		return new_bigint_value(v)
	}

	n := big.integer_from_string(x)!
	if n >= big.integer_from_i64(min_i64) && n <= big.integer_from_i64(max_i64) {
		return new_bigint_value(x.i64())
	}

	return new_numeric_value(x)
}
