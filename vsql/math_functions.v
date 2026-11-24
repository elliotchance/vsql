module vsql

import math
import math.big
import rand

// The mathematical functions that the SQL standard doesn't have, but other
// databases do (V403-02 to V403-17): most of them have ROUND to CBRT, while
// FACTORIAL, GCD, LCM, ERF, ERFC, GAMMA and LGAMMA come from PostgreSQL. Like the
// standard ones, an exact number is implicitly cast to a NUMERIC and an
// approximate number to a DOUBLE PRECISION (see find_function), and the result
// is NULL when any argument is NULL.

fn register_math_funcs(mut conn Connection) ! {
	double_precision := Type{SQLType.is_double_precision, 0, 0, false, false}
	numeric := Type{SQLType.is_numeric, 0, 0, false, false}
	smallint := Type{SQLType.is_smallint, 0, 0, false, false}
	integer := Type{SQLType.is_integer, 0, 0, false, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}

	// ROUND and TRUNC have an optional number of decimal places, which can be
	// negative to round to the left of the decimal point. Any integer is
	// implicitly cast to a BIGINT. The declared type of a NUMERIC result is set
	// by rounding_function_type.
	for name in ['ROUND', 'TRUNC'] {
		feature := if name == 'ROUND' { vsql_round } else { vsql_trunc }
		truncate := name == 'TRUNC'
		conn.register_func(Func{name, [double_precision], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return round_double(args[0].f64_value(), 0, truncate)
		}, double_precision, false, true, [feature], [], false})!
		conn.register_func(Func{name, [double_precision, bigint], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return round_double(args[0].f64_value(), args[1].int_value(), truncate)
		}, double_precision, false, true, [feature], [], false})!
		conn.register_func(Func{name, [numeric], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return new_numeric_value_from_numeric(round_numeric(args[0].numeric_value(),
				0, truncate))
		}, numeric, false, true, [feature], [], false})!
		conn.register_func(Func{name, [numeric, bigint], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return new_numeric_value_from_numeric(round_numeric(args[0].numeric_value(),
				args[1].int_value(), truncate))
		}, numeric, false, true, [feature], [], false})!
	}

	// SIGN of an integer has the same type, so it doesn't need a cast.
	conn.register_func(Func{'SIGN', [double_precision], false, func_sign, double_precision, false, true, [
		vsql_sign,
	], [], false})!
	conn.register_func(Func{'SIGN', [numeric], false, func_sign_numeric, numeric, false, true, [
		vsql_sign,
	], [], false})!
	for typ in [smallint, integer, bigint] {
		conn.register_func(Func{'SIGN', [typ], false, func_sign_integer, typ, false, true, [
			vsql_sign,
		], [], false})!
	}

	// FACTORIAL is exact, so the result is a NUMERIC that can hold all of its
	// digits. Any integer is implicitly cast to a BIGINT.
	conn.register_func(Func{'FACTORIAL', [bigint], false, func_factorial, numeric, false, true, [
		vsql_factorial,
	], [], false})!

	// Like MOD, GCD and LCM have a version for each combination of integer
	// types. The result has the larger of the two types.
	integer_types := [smallint, integer, bigint]
	for i, a in integer_types {
		for j, b in integer_types {
			result_type := if i > j { a } else { b }
			conn.register_func(Func{'GCD', [a, b], false, fn [result_type] (_ FunctionContext, args []Value) !Value {
				return integer_function_result(gcd_u64(abs_u64(args[0].int_value()), abs_u64(args[1].int_value())),
					result_type)
			}, result_type, false, true, [vsql_gcd], [], false})!
			conn.register_func(Func{'LCM', [a, b], false, fn [result_type] (_ FunctionContext, args []Value) !Value {
				return integer_function_result(lcm_u64(abs_u64(args[0].int_value()), abs_u64(args[1].int_value()))!,
					result_type)
			}, result_type, false, true, [vsql_lcm], [], false})!
		}
	}

	conn.register_func(Func{'PI', [], false, func_pi, double_precision, false, true, [
		vsql_pi,
	], [], false})!

	// RANDOM() is a different value each time it's called, so it's NOT
	// DETERMINISTIC, like NOW().
	conn.register_func(Func{'RANDOM', [], false, func_random, double_precision, false, false, [
		vsql_random,
	], [], false})!
	register_random_funcs(mut conn)!

	conn.register_func(Func{'ATAN2', [double_precision, double_precision], false, func_atan2, double_precision, false, true, [
		vsql_atan2,
	], [], false})!
	conn.register_func(Func{'DEGREES', [double_precision], false, func_degrees, double_precision, false, true, [
		vsql_degrees,
	], [], false})!
	conn.register_func(Func{'RADIANS', [double_precision], false, func_radians, double_precision, false, true, [
		vsql_radians,
	], [], false})!
	conn.register_func(Func{'CBRT', [double_precision], false, func_cbrt, double_precision, false, true, [
		vsql_cbrt,
	], [], false})!
	conn.register_func(Func{'ERF', [double_precision], false, func_erf, double_precision, false, true, [
		vsql_erf,
	], [], false})!
	conn.register_func(Func{'ERFC', [double_precision], false, func_erfc, double_precision, false, true, [
		vsql_erfc,
	], [], false})!
	conn.register_func(Func{'GAMMA', [double_precision], false, func_gamma, double_precision, false, true, [
		vsql_gamma,
	], [], false})!
	conn.register_func(Func{'LGAMMA', [double_precision], false, func_lgamma, double_precision, false, true, [
		vsql_lgamma,
	], [], false})!

	// TRIM_SCALE and MIN_SCALE come from PostgreSQL. Any exact number is
	// implicitly cast to a NUMERIC with the same precision and scale. The
	// result of TRIM_SCALE is a DECFLOAT(34), see func_trim_scale.
	conn.register_func(Func{'TRIM_SCALE', [numeric], false, func_trim_scale, Type{.is_decfloat, max_decfloat_precision, 0, false, false}, false, true, [
		vsql_trim_scale,
	], [], false})!
	conn.register_func(Func{'MIN_SCALE', [numeric], false, func_min_scale, integer, false, true, [
		vsql_min_scale,
	], [], false})!
}

// min_scale is the fewest decimal places that n can have without changing its
// value, which is its scale without the trailing zeros.
fn min_scale(n Numeric) int {
	s := n.str()
	if !s.contains('.') {
		return 0
	}

	return s.all_after('.').trim_right('0').len
}

// TRIM_SCALE(NUMERIC) DECFLOAT(34)
//
// The result is the same number with only the decimal places that it needs
// (see min_scale). Every value of a NUMERIC has exactly the scale of its type,
// so the result can't be a NUMERIC. A DECFLOAT has the decimal places of each
// value instead, so it's a DECFLOAT(34), and a number with more than 34
// significant digits is rounded, like a CAST (see cast_to_decfloat).
fn func_trim_scale(_ FunctionContext, args []Value) !Value {
	d := cast_to_decfloat(args[0], Type{.is_decfloat, max_decfloat_precision, 0, false, false})!

	return new_decfloat_value(d.typ, trim_scale_decfloat(d.decfloat_value()))
}

// MIN_SCALE(NUMERIC) INTEGER
fn func_min_scale(_ FunctionContext, args []Value) !Value {
	return new_integer_value(min_scale(args[0].numeric_value()))
}

// round_double rounds x to places decimal places, half away from zero, or
// truncates it towards zero.
fn round_double(x f64, places i64, truncate bool) !Value {
	round := fn [truncate] (y f64) f64 {
		return if truncate { math.trunc(y) } else { math.round(y) }
	}

	// A DOUBLE PRECISION has at most 17 significant digits and its exponent is
	// between -324 and 308, so there's nothing to round past 340 places. Before
	// -310 places, every value rounds to 0.
	if places > 340 || math.is_nan(x) || math.is_inf(x, 0) {
		return new_double_precision_value(x)
	}
	if places < -310 {
		return new_double_precision_value(0)
	}

	if places >= 0 {
		factor := math.pow(10, f64(places))
		scaled := x * factor
		// The scaled value is too large to have a fractional part.
		if math.is_inf(scaled, 0) || math.abs(scaled) >= 4503599627370496 {
			return new_double_precision_value(x)
		}

		return new_double_precision_value(round(scaled) / factor)
	}

	factor := math.pow(10, f64(-places))
	return approximate_value(round(x / factor) * factor, .is_double_precision)
}

// round_numeric rounds n to places decimal places, half away from zero, or
// truncates it towards zero. The result has a scale of places, or 0 if places
// is negative. It's exact, so it may need one more digit than n, such as
// ROUND(9.5) = 10.
fn round_numeric(n Numeric, places i64, truncate bool) Numeric {
	// There's nothing to round when n has no more than places digits after the
	// decimal point.
	if places >= i64(n.typ.scale) {
		return n
	}

	typ := Type{.is_numeric, 0, if places > 0 { int(places) } else { 0 }, false, false}

	// Every digit of n is to the right of the place it's rounded to, so it's 0,
	// even if the first digit is 5 or more. The integer part of n has fewer
	// digits than its precision.
	if places < -i64(n.typ.numeric_precision()) {
		return new_numeric(typ, big.zero_int, big.one_int)
	}

	// The absolute value is rounded so that the half is away from zero, then the
	// sign is put back.
	numerator := n.numerator.abs()
	ten := big.integer_from_int(10)
	factor := ten.pow(u32(math.abs(places)))
	mut divisor := n.denominator
	mut dividend := numerator
	if places >= 0 {
		dividend = numerator * factor
	} else {
		divisor = n.denominator * factor
	}

	mut quotient := dividend / divisor
	remainder := dividend - quotient * divisor
	if !truncate && !(remainder * big.integer_from_int(2) < divisor) {
		quotient = quotient + big.one_int
	}
	if n.is_negative() {
		quotient = big.zero_int - quotient
	}

	if places >= 0 {
		return new_numeric(typ, quotient, factor)
	}

	return new_numeric(typ, quotient * factor, big.one_int)
}

// rounding_function_type is the declared type of ROUND and TRUNC of a NUMERIC
// (or DECIMAL) with a precision of p and a scale of s. The result has a scale
// of places (between 0 and s), or s when places isn't a constant. ROUND may
// need one more digit for the integer part, such as ROUND(9.5) = 10.
fn rounding_function_type(name string, arg Type, places ?i64) Type {
	p, s := arg.exact_precision(), arg.scale
	mut scale := s
	if k := places {
		scale = if k < 0 {
			0
		} else if k < s {
			int(k)
		} else {
			s
		}
	}

	if p == 0 {
		return Type{.is_numeric, 0, scale, false, false}
	}

	mut size := p - s + scale
	if name == 'ROUND' && scale < s {
		size++
	}
	if size < 1 {
		size = 1
	}

	return Type{.is_numeric, size, scale, false, false}
}

// SIGN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sign(_ FunctionContext, args []Value) !Value {
	x := args[0].f64_value()
	if x > 0 {
		return new_double_precision_value(1)
	}
	if x < 0 {
		return new_double_precision_value(-1)
	}

	return new_double_precision_value(0)
}

// SIGN(NUMERIC) NUMERIC(1)
fn func_sign_numeric(_ FunctionContext, args []Value) !Value {
	n := args[0].numeric_value()
	if n.is_negative() {
		return new_numeric_value('-1')
	}
	if n.is_zero() {
		return new_numeric_value('0')
	}

	return new_numeric_value('1')
}

// SIGN(SMALLINT) SMALLINT
// SIGN(INTEGER) INTEGER
// SIGN(BIGINT) BIGINT
fn func_sign_integer(_ FunctionContext, args []Value) !Value {
	x := args[0].int_value()
	sign := if x > 0 {
		1
	} else if x < 0 {
		-1
	} else {
		0
	}

	return match args[0].typ.typ {
		.is_smallint { new_smallint_value(i16(sign)) }
		.is_integer { new_integer_value(sign) }
		else { new_bigint_value(sign) }
	}
}

// max_factorial is the largest n for which n! has no more than
// max_numeric_precision digits (449! has 998 digits, 450! has 1001).
const max_factorial = 449

// FACTORIAL(BIGINT) NUMERIC
fn func_factorial(_ FunctionContext, args []Value) !Value {
	n := args[0].int_value()
	if n < 0 || n > max_factorial {
		return sqlstate_22003()
	}

	mut result := big.one_int
	for i in 2 .. n + 1 {
		result = result * big.integer_from_i64(i)
	}

	return new_numeric_value_from_numeric(new_numeric(Type{.is_numeric, 0, 0, false, false},
		result, big.one_int))
}

// abs_u64 is the absolute value of x, which fits in a u64 even for the
// smallest BIGINT.
fn abs_u64(x i64) u64 {
	return if x < 0 { u64(0) - u64(x) } else { u64(x) }
}

// gcd_u64 is the greatest common divisor of a and b, or 0 if they're both 0.
fn gcd_u64(a u64, b u64) u64 {
	mut x, mut y := a, b
	for y != 0 {
		x, y = y, x % y
	}

	return x
}

// lcm_u64 is the least common multiple of a and b, or 0 if either is 0. A
// result that doesn't fit in a u64 is a 22003 error.
fn lcm_u64(a u64, b u64) !u64 {
	if a == 0 || b == 0 {
		return 0
	}

	x := a / gcd_u64(a, b)
	if b > max_u64 / x {
		return sqlstate_22003()
	}

	return x * b
}

// integer_function_result is the result of GCD or LCM as a SMALLINT, INTEGER or
// BIGINT. A result that doesn't fit in the type is a 22003 error.
fn integer_function_result(x u64, typ Type) !Value {
	return match typ.typ {
		.is_smallint {
			if x > u64(max_i16) {
				return sqlstate_22003()
			}
			new_smallint_value(i16(x))
		}
		.is_integer {
			if x > u64(max_i32) {
				return sqlstate_22003()
			}
			new_integer_value(int(x))
		}
		else {
			if x > u64(max_i64) {
				return sqlstate_22003()
			}
			new_bigint_value(i64(x))
		}
	}
}

// PI() DOUBLE PRECISION
fn func_pi(_ FunctionContext, _ []Value) !Value {
	return new_double_precision_value(math.pi)
}

// RANDOM() DOUBLE PRECISION
fn func_random(_ FunctionContext, _ []Value) !Value {
	return new_double_precision_value(rand.f64())
}

// ATAN2(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_atan2(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.atan2(args[0].f64_value(), args[1].f64_value()))
}

// DEGREES(DOUBLE PRECISION) DOUBLE PRECISION
fn func_degrees(_ FunctionContext, args []Value) !Value {
	return approximate_value(args[0].f64_value() * (180 / math.pi), .is_double_precision)
}

// RADIANS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_radians(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(args[0].f64_value() * (math.pi / 180))
}

// CBRT(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cbrt(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.cbrt(args[0].f64_value()))
}

// ERF(DOUBLE PRECISION) DOUBLE PRECISION
fn func_erf(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.erf(args[0].f64_value()))
}

// ERFC(DOUBLE PRECISION) DOUBLE PRECISION
fn func_erfc(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.erfc(args[0].f64_value()))
}

// is_gamma_pole is true when gamma of x is undefined: 0 and the negative
// integers. Every DOUBLE PRECISION from -2^52 down is an integer.
fn is_gamma_pole(x f64) bool {
	return x == 0 || (x < 0 && x == math.floor(x))
}

// GAMMA(DOUBLE PRECISION) DOUBLE PRECISION
fn func_gamma(_ FunctionContext, args []Value) !Value {
	x := args[0].f64_value()
	if is_gamma_pole(x) {
		return sqlstate_22003()
	}

	// A result that is too large (from a large x, or an x very close to 0) is
	// an error. One that is too small, such as GAMMA(-200.5), is 0 (adding 0
	// turns -0 into 0).
	return approximate_value(math.gamma(x) + 0, .is_double_precision)
}

// LGAMMA(DOUBLE PRECISION) DOUBLE PRECISION
fn func_lgamma(_ FunctionContext, args []Value) !Value {
	x := args[0].f64_value()
	if is_gamma_pole(x) {
		return sqlstate_22003()
	}

	// Only a very large x is too large, such as LGAMMA(1e308).
	return approximate_value(math.log_gamma(x), .is_double_precision)
}
