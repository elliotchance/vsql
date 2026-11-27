module vsql

import crypto.rand as crypto_rand
import math
import math.big
import rand

// The random functions other than RANDOM() (see register_math_funcs):
// RANDOM(min, max) (V403-24) and RANDOM_NORMAL (V403-25) come from PostgreSQL,
// and RANDOM_BINARY (V403-26) is like SQLite's randomblob. They're a different
// value each time they're called, so they're NOT DETERMINISTIC, and the result
// is NULL when any argument is NULL.

fn register_random_funcs(mut conn Connection) ! {
	double_precision := Type{SQLType.is_double_precision, 0, 0, false, false}

	// RANDOM(min, max) has the declared type of min and max combined (see
	// random_range_type), and both arguments are cast to it before it's called.
	// These are only the types that the arguments are found with.
	for typ in [
		Type{SQLType.is_bigint, 0, 0, false, false},
		Type{SQLType.is_numeric, 0, 0, false, false},
		double_precision,
		Type{SQLType.is_decfloat, max_decfloat_precision, 0, false, false},
	] {
		conn.register_func(Func{'RANDOM', [typ, typ], false, func_random_range, typ, false, false, [
			vsql_random_range,
		], [], false})!
	}

	// The mean and standard deviation are optional, and they default to 0 and 1.
	conn.register_func(Func{'RANDOM_NORMAL', [], false, func_random_normal, double_precision, false, false, [
		vsql_random_normal,
	], [], false})!
	conn.register_func(Func{'RANDOM_NORMAL', [double_precision], false, func_random_normal, double_precision, false, false, [
		vsql_random_normal,
	], [], false})!
	conn.register_func(Func{'RANDOM_NORMAL', [double_precision, double_precision], false, func_random_normal, double_precision, false, false, [
		vsql_random_normal,
	], [], false})!

	// Any integer is implicitly cast to a BIGINT.
	conn.register_func(Func{'RANDOM_BINARY', [Type{SQLType.is_bigint, 0, 0, false, false}], false, func_random_binary, Type{SQLType.is_varbinary, max_binary_length, 0, false, false}, false, false, [
		vsql_random_binary,
	], [], false})!
}

// random_range_type is the declared type of RANDOM(min, max), which is the
// declared types of min and max combined, like a CASE or a UNION.
//
// ISO/IEC 9075-2:2023, 9.5, Result of data type combinations
fn random_range_type(min Type, max Type) Type {
	// Both are numbers (see register_random_funcs), so they can always be
	// combined.
	return combine_types(min, max) or { Type{SQLType.is_double_precision, 0, 0, false, false} }
}

// random_big_integer is a random integer from 0 to n (inclusive), where every
// value is equally likely. It uses random bits until one is in the range, so
// it isn't biased like a remainder would be.
fn random_big_integer(n big.Integer) big.Integer {
	if n.signum <= 0 {
		return big.zero_int
	}

	bits := n.bit_len()
	mask := u8((1 << (((bits - 1) % 8) + 1)) - 1)
	for {
		mut b := []u8{len: (bits + 7) / 8}
		for i in 0 .. b.len {
			b[i] = rand.u8()
		}
		b[0] &= mask
		x := big.integer_from_bytes(b)
		if !(n < x) {
			return x
		}
	}
}

// RANDOM(min, max)
//
// An exact number is from min to max (inclusive), with the scale of the
// declared type, and every possible value is equally likely. An approximate
// number (or DECFLOAT) is at least min and less than max, like
// min + RANDOM() * (max - min). If min = max, the result is min.
fn func_random_range(_ FunctionContext, args []Value) !Value {
	typ := args[0].typ
	if typ.typ in [.is_smallint, .is_integer, .is_bigint] {
		min, max := args[0].int_value(), args[1].int_value()
		if min > max {
			return random_range_error(args)
		}

		// The range of a BIGINT may not fit in an i64, so it's a big.Integer.
		n := random_big_integer(big.integer_from_i64(max) - big.integer_from_i64(min))
		x := big_integer_to_i64(big.integer_from_i64(min) + n)
		return match typ.typ {
			.is_smallint { new_smallint_value(i16(x)) }
			.is_integer { new_integer_value(int(x)) }
			else { new_bigint_value(x) }
		}
	}
	if typ.typ in [.is_numeric, .is_decimal] {
		a, b := args[0].numeric_value(), args[1].numeric_value()
		if a.greater_than(b) {
			return random_range_error(args)
		}

		// A NUMERIC without a precision has the scale of each value, so the
		// larger one is used.
		scale := if typ.size == 0 { int_max(min_scale(a), min_scale(b)) } else { typ.scale }
		denominator := pow10(scale)
		min := scaled_integer(a, denominator)
		n := random_big_integer(scaled_integer(b, denominator) - min)
		result := new_numeric(Type{typ.typ, typ.size, i16(scale), false, false}, min + n,
			denominator)
		if typ.typ == .is_decimal {
			return new_decimal_value_from_numeric(result)
		}

		return new_numeric_value_from_numeric(result)
	}
	if typ.typ == .is_decfloat {
		a, b := args[0].decfloat_value(), args[1].decfloat_value()
		match compare_decfloat(a, b) {
			.is_greater {
				return random_range_error(args)
			}
			.is_equal {
				return args[0]
			}
			else {}
		}

		// A random fraction with p digits, which is at least 0 and less than 1.
		p := typ.size
		width := b.subtract(a, p)!
		for {
			fraction := DecFloat{random_big_integer(pow10(p) - big.one_int), -p}
			x := a.add(width.multiply(fraction, p)!, p)!
			if compare_decfloat(x, b) == .is_less {
				return new_decfloat_value(typ, x)
			}
		}
	}

	min, max := args[0].f64_value(), args[1].f64_value()
	if min > max {
		return random_range_error(args)
	}
	if min == max {
		return args[0]
	}

	// The result is rounded, so it may round up to max, which isn't in
	// the range.
	for {
		r := rand.f64()
		mut x := min + r * (max - min)
		if math.is_inf(x, 0) {
			// max - min is too large for a DOUBLE PRECISION.
			x = min * (1 - r) + max * r
		}
		if typ.typ == .is_real {
			if f32(x) < f32(max) && f32(x) >= f32(min) {
				return new_real_value(f32(x))
			}
		} else if x < max && x >= min {
			return new_double_precision_value(x)
		}
	}
}

// scaled_integer is n * denominator, which is an integer because n has no more
// decimal places than the denominator (10^scale).
fn scaled_integer(n Numeric, denominator big.Integer) big.Integer {
	if n.is_zero() {
		return big.zero_int
	}

	return n.scale_numerator(denominator).numerator
}

fn random_range_error(args []Value) IError {
	return sqlstate_22023('RANDOM minimum ${args[0].str()} is greater than maximum ${args[1].str()}')
}

// RANDOM_NORMAL([mean [, stddev]])
//
// A normally distributed number, using the Box-Muller transform with the same
// generator as RANDOM().
fn func_random_normal(_ FunctionContext, args []Value) !Value {
	mean := if args.len > 0 { args[0].f64_value() } else { 0.0 }
	stddev := if args.len > 1 { args[1].f64_value() } else { 1.0 }
	if stddev < 0 {
		return sqlstate_22023('RANDOM_NORMAL standard deviation must not be negative')
	}
	if stddev == 0 {
		return new_double_precision_value(mean)
	}

	// u1 is greater than 0 (RANDOM() can be 0), so its logarithm is finite.
	u1 := 1 - rand.f64()
	u2 := rand.f64()
	z := math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)

	return approximate_value(mean + stddev * z, .is_double_precision)
}

// RANDOM_BINARY(n)
//
// n random bytes from a cryptographically secure generator, unlike RANDOM().
fn func_random_binary(_ FunctionContext, args []Value) !Value {
	n := args[0].int_value()
	if n < 0 || n > max_binary_length {
		return sqlstate_22023('RANDOM_BINARY length must be from 0 to ${max_binary_length}')
	}

	// crypto.rand.read() fails for 0 bytes on Windows.
	if n == 0 {
		return new_binary_string_value(.is_varbinary, '')
	}

	bytes := crypto_rand.bytes(int(n)) or { return err }

	return new_binary_string_value(.is_varbinary, bytes.bytestr())
}

// random_arg_names are the names of the parameters of the functions in this
// file (see builtin_arg_names).
const random_arg_names = {
	'RANDOM':        ['MIN', 'MAX']
	'RANDOM_BINARY': ['N']
	'RANDOM_NORMAL': ['MEAN', 'STDDEV']
}
