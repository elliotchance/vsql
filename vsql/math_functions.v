module vsql

import math
import math.big
import rand

// The mathematical functions that the SQL standard doesn't have, but most other
// databases do (V403-02 to V403-10). Like the standard ones, an exact number is
// implicitly cast to a NUMERIC and an approximate number to a DOUBLE PRECISION
// (see find_function), and the result is NULL when any argument is NULL.

fn register_math_funcs(mut conn Connection) ! {
	double_precision := Type{SQLType.is_double_precision, 0, 0, false}
	numeric := Type{SQLType.is_numeric, 0, 0, false}
	smallint := Type{SQLType.is_smallint, 0, 0, false}
	integer := Type{SQLType.is_integer, 0, 0, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false}

	// ROUND and TRUNC have an optional number of decimal places, which can be
	// negative to round to the left of the decimal point. Any integer is
	// implicitly cast to a BIGINT. The declared type of a NUMERIC result is set
	// by rounding_function_type.
	for name in ['ROUND', 'TRUNC'] {
		feature := if name == 'ROUND' { vsql_round } else { vsql_trunc }
		truncate := name == 'TRUNC'
		conn.register_func(Func{name, [double_precision], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return round_double(args[0].f64_value(), 0, truncate)
		}, double_precision, false, true, [feature]})!
		conn.register_func(Func{name, [double_precision, bigint], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return round_double(args[0].f64_value(), args[1].int_value(), truncate)
		}, double_precision, false, true, [feature]})!
		conn.register_func(Func{name, [numeric], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return new_numeric_value_from_numeric(round_numeric(args[0].numeric_value(),
				0, truncate))
		}, numeric, false, true, [feature]})!
		conn.register_func(Func{name, [numeric, bigint], false, fn [truncate] (_ FunctionContext, args []Value) !Value {
			return new_numeric_value_from_numeric(round_numeric(args[0].numeric_value(),
				args[1].int_value(), truncate))
		}, numeric, false, true, [feature]})!
	}

	// SIGN of an integer has the same type, so it doesn't need a cast.
	conn.register_func(Func{'SIGN', [double_precision], false, func_sign, double_precision, false, true, [
		vsql_sign,
	]})!
	conn.register_func(Func{'SIGN', [numeric], false, func_sign_numeric, numeric, false, true, [
		vsql_sign,
	]})!
	for typ in [smallint, integer, bigint] {
		conn.register_func(Func{'SIGN', [typ], false, func_sign_integer, typ, false, true, [
			vsql_sign,
		]})!
	}

	conn.register_func(Func{'PI', [], false, func_pi, double_precision, false, true, [
		vsql_pi,
	]})!

	// RANDOM() is a different value each time it's called, so it's NOT
	// DETERMINISTIC, like NOW().
	conn.register_func(Func{'RANDOM', [], false, func_random, double_precision, false, false, [
		vsql_random,
	]})!

	conn.register_func(Func{'ATAN2', [double_precision, double_precision], false, func_atan2, double_precision, false, true, [
		vsql_atan2,
	]})!
	conn.register_func(Func{'DEGREES', [double_precision], false, func_degrees, double_precision, false, true, [
		vsql_degrees,
	]})!
	conn.register_func(Func{'RADIANS', [double_precision], false, func_radians, double_precision, false, true, [
		vsql_radians,
	]})!
	conn.register_func(Func{'CBRT', [double_precision], false, func_cbrt, double_precision, false, true, [
		vsql_cbrt,
	]})!
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

	typ := Type{.is_numeric, 0, if places > 0 { int(places) } else { 0 }, false}

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
		return Type{.is_numeric, 0, scale, false}
	}

	mut size := p - s + scale
	if name == 'ROUND' && scale < s {
		size++
	}
	if size < 1 {
		size = 1
	}

	return Type{.is_numeric, size, scale, false}
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
