module vsql

import math

// ISO/IEC 9075-2:2023, 6.31, <numeric value function>
//
// Specify a function yielding a value of type numeric.

// POSITION(CHARACTER VARYING IN CHARACTER VARYING) INTEGER
fn func_position(_ FunctionContext, args []Value) !Value {
	// An empty string is found at the start of any string, even an empty one.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 2.a
	if args[0].string_value() == '' {
		return new_integer_value(1)
	}

	s := args[1].string_value()
	index := s.index(args[0].string_value()) or { return new_integer_value(0) }

	// The position is counted in characters, not bytes.
	return new_integer_value(s[..index].len_utf8() + 1)
}

// CHAR_LENGTH(CHARACTER VARYING) INTEGER
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 5.b
fn func_char_length(_ FunctionContext, args []Value) !Value {
	return new_integer_value(args[0].string_value().runes().len)
}

// OCTET_LENGTH(CHARACTER VARYING) INTEGER
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 6
fn func_octet_length(_ FunctionContext, args []Value) !Value {
	return new_integer_value(args[0].string_value().len)
}

// UPPER(CHARACTER VARYING) CHARACTER VARYING
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 7.d.i
fn func_upper(_ FunctionContext, args []Value) !Value {
	s := args[0].string_value()
	if s.is_pure_ascii() {
		return new_varchar_value(s.to_upper_ascii())
	}

	return new_varchar_value(replace_case_mappings(s, upper_case_mappings))
}

// LOWER(CHARACTER VARYING) CHARACTER VARYING
//
// ISO/IEC 9075-2:2023, 6.33, <string value function>, General Rules, 7.d.ii
fn func_lower(_ FunctionContext, args []Value) !Value {
	s := args[0].string_value()
	if s.is_pure_ascii() {
		return new_varchar_value(s.to_lower_ascii())
	}

	return new_varchar_value(replace_case_mappings(s, lower_case_mappings))
}

// CaseMapping replaces a character with one to three characters. The unused
// characters are zero.
struct CaseMapping {
	from rune
	to1  rune
	to2  rune
	to3  rune
}

// replace_case_mappings replaces each character that has a mapping, which may
// make the string longer.
fn replace_case_mappings(s string, mappings []CaseMapping) string {
	mut result := []rune{cap: s.len}
	for c in s.runes() {
		i := find_case_mapping(c, mappings)
		if i < 0 {
			result << c
			continue
		}

		m := mappings[i]
		result << m.to1
		if m.to2 != 0 {
			result << m.to2
		}
		if m.to3 != 0 {
			result << m.to3
		}
	}

	return result.string()
}

// find_case_mapping returns the index of the mapping for c, or -1 if it doesn't
// have one. The mappings are ordered by from.
fn find_case_mapping(c rune, mappings []CaseMapping) int {
	mut low := 0
	mut high := mappings.len - 1
	for low <= high {
		middle := (low + high) / 2
		from := mappings[middle].from
		if from == c {
			return middle
		}
		if from < c {
			low = middle + 1
		} else {
			high = middle - 1
		}
	}

	return -1
}

// ABS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_abs(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.abs(args[0].f64_value()))
}

// ABS(NUMERIC) NUMERIC
fn func_abs_numeric(_ FunctionContext, args []Value) !Value {
	n := args[0].numeric_value()
	if n.is_negative() {
		return new_numeric_value_from_numeric(n.neg())
	}

	return args[0]
}

// ABS(DECIMAL) DECIMAL
fn func_abs_decimal(_ FunctionContext, args []Value) !Value {
	n := args[0].numeric_value()
	if n.is_negative() {
		return new_decimal_value_from_numeric(n.neg())
	}

	return args[0]
}

// ABS(SMALLINT) SMALLINT
// ABS(INTEGER) INTEGER
// ABS(BIGINT) BIGINT
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 8.c
fn func_abs_integer(_ FunctionContext, args []Value) !Value {
	x := args[0].int_value()
	if x >= 0 {
		return args[0]
	}

	// The smallest value of each type has no positive equivalent.
	if x == min_i64 {
		return sqlstate_22003()
	}
	check_integer_range(-x, args[0].typ.typ)!

	return match args[0].typ.typ {
		.is_smallint { new_smallint_value(i16(-x)) }
		.is_integer { new_integer_value(int(-x)) }
		else { new_bigint_value(-x) }
	}
}

// ABS(REAL) REAL
fn func_abs_real(_ FunctionContext, args []Value) !Value {
	return new_real_value(f32(math.abs(args[0].f64_value())))
}

// SIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sin(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.sin(args[0].f64_value()))
}

// COS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cos(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.cos(args[0].f64_value()))
}

// TAN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_tan(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.tan(args[0].f64_value()))
}

// SINH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sinh(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.sinh(args[0].f64_value()))
}

// COSH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cosh(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.cosh(args[0].f64_value()))
}

// TANH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_tanh(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.tanh(args[0].f64_value()))
}

// ASIN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_asin(_ FunctionContext, args []Value) !Value {
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 10.b.ii.1
	if args[0].f64_value() < -1 || args[0].f64_value() > 1 {
		return sqlstate_22003()
	}

	return new_double_precision_value(math.asin(args[0].f64_value()))
}

// ACOS(DOUBLE PRECISION) DOUBLE PRECISION
fn func_acos(_ FunctionContext, args []Value) !Value {
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 10.b.i.1
	if args[0].f64_value() < -1 || args[0].f64_value() > 1 {
		return sqlstate_22003()
	}

	return new_double_precision_value(math.acos(args[0].f64_value()))
}

// ATAN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_atan(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.atan(args[0].f64_value()))
}

// MOD(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_mod(_ FunctionContext, args []Value) !Value {
	if args[1].f64_value() == 0 {
		return sqlstate_22012() // division by zero
	}

	return new_double_precision_value(math.fmod(args[0].f64_value(), args[1].f64_value()))
}

// MOD(NUMERIC, NUMERIC) NUMERIC
fn func_mod_numeric(_ FunctionContext, args []Value) !Value {
	value := args[0].numeric_value()
	modulus := args[1].numeric_value()

	return new_numeric_value_from_numeric(value.subtract(value.divide(modulus)!.trunc().multiply(modulus)))
}

// MOD(SMALLINT, SMALLINT) SMALLINT
// MOD(INTEGER, INTEGER) INTEGER
// MOD(BIGINT, BIGINT) BIGINT
// (and the other combinations of integer types)
//
// The result has the sign of the dividend and the type of the divisor, which it
// always fits in because it's smaller than the divisor.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 9
fn func_mod_integer(_ FunctionContext, args []Value) !Value {
	value := args[0].int_value()
	modulus := args[1].int_value()
	if modulus == 0 {
		return sqlstate_22012() // division by zero
	}

	// The remainder of dividing by -1 is always 0, but min_i64 % -1 overflows.
	result := if modulus == -1 { i64(0) } else { value % modulus }

	return match args[1].typ.typ {
		.is_smallint { new_smallint_value(i16(result)) }
		.is_integer { new_integer_value(int(result)) }
		else { new_bigint_value(result) }
	}
}

// LOG(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_log(_ FunctionContext, args []Value) !Value {
	base := args[0].f64_value()
	x := args[1].f64_value()

	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 11.b and 11.c
	if x <= 0 || base <= 0 || base == 1 {
		return sqlstate_22003()
	}

	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 11.d
	//
	// Bases 2 and 10 are calculated directly, so that LOG(10, 1000) is exactly 3
	// (the same as LOG10(1000)) instead of 2.9999999999999996.
	result := if base == 2 {
		math.log2(x)
	} else if base == 10 {
		math.log10(x)
	} else {
		math.log(x) / math.log(base)
	}

	return new_double_precision_value(result)
}

// LOG10(DOUBLE PRECISION) DOUBLE PRECISION
fn func_log10(_ FunctionContext, args []Value) !Value {
	// LOG10(x) is LOG(10, x).
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 15
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 11.b
	if args[0].f64_value() <= 0 {
		return sqlstate_22003()
	}

	return new_double_precision_value(math.log10(args[0].f64_value()))
}

// LN(DOUBLE PRECISION) DOUBLE PRECISION
fn func_ln(_ FunctionContext, args []Value) !Value {
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 12.b
	if args[0].f64_value() <= 0 {
		return sqlstate_2201e()
	}

	return new_double_precision_value(math.log(args[0].f64_value()))
}

// EXP(DOUBLE PRECISION) DOUBLE PRECISION
fn func_exp(_ FunctionContext, args []Value) !Value {
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 13.b
	return approximate_nonzero_value(math.exp(args[0].f64_value()), .is_double_precision)
}

// SQRT(DOUBLE PRECISION) DOUBLE PRECISION
fn func_sqrt(_ FunctionContext, args []Value) !Value {
	// SQRT(x) is POWER(x, 0.5), so x can't be negative.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 19
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 14.e
	if args[0].f64_value() < 0 {
		return sqlstate_2201f()
	}

	return new_double_precision_value(math.sqrt(args[0].f64_value()))
}

// POWER(DOUBLE PRECISION, DOUBLE PRECISION) DOUBLE PRECISION
fn func_power(_ FunctionContext, args []Value) !Value {
	base := args[0].f64_value()
	exponent := args[1].f64_value()

	// A zero base can't have a negative exponent, and a negative base needs a
	// whole number exponent.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 14.b and 14.e
	if (base == 0 && exponent < 0) || (base < 0 && exponent != math.trunc(exponent)) {
		return sqlstate_2201f()
	}

	if base != 0 {
		return approximate_nonzero_value(math.pow(base, exponent), .is_double_precision)
	}

	return approximate_value(math.pow(base, exponent), .is_double_precision)
}

// FLOOR(DOUBLE PRECISION) DOUBLE PRECISION
fn func_floor(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.floor(args[0].f64_value()))
}

// FLOOR(NUMERIC) NUMERIC
fn func_floor_numeric(_ FunctionContext, args []Value) !Value {
	n := args[0].numeric_value()
	t := n.trunc()
	if n.is_negative() && !n.equals(t) {
		return new_numeric_value_from_numeric(t.subtract(new_numeric_from_string('1')).trunc())
	}

	return new_numeric_value_from_numeric(t)
}

// WIDTH_BUCKET(NUMERIC, NUMERIC, NUMERIC, COUNT) COUNT
// WIDTH_BUCKET(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, COUNT) COUNT
//
// The range between the bounds is split into count buckets of the same width,
// numbered from 1, and the result is the bucket that the operand is in. The
// range includes the first bound but not the second. An operand before the
// range is in bucket 0, and one after it is in bucket count + 1. The bounds can
// be in either order, so the buckets can go down instead.
//
// The result is calculated exactly, even for approximate numbers, so an
// operand is never put in the wrong bucket by rounding. It's cast to the type
// of the count afterwards, which can be out of range for count + 1 (see
// RoutineInvocation.compile).
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 17
fn func_width_bucket(_ FunctionContext, args []Value) !Value {
	operand := args[0].as_numeric()!
	bound1 := args[1].as_numeric()!
	bound2 := args[2].as_numeric()!
	count := args[3].as_numeric()!
	if count.is_negative() || count.is_zero() || bound1.equals(bound2) {
		return sqlstate_2201g()
	}

	// The distance from the start of the range, and the width of the range, are
	// both positive when the operand is in the range.
	mut distance := operand.subtract(bound1)
	mut width := bound2.subtract(bound1)
	if bound1.greater_than(bound2) {
		distance = distance.neg()
		width = width.neg()
	}

	if distance.is_negative() {
		return new_numeric_value('0')
	}
	if !distance.less_than(width) {
		return new_numeric_value_from_numeric(count.add(new_numeric_from_string('1')))
	}

	// The quotient isn't negative, so truncating it is the same as its floor.
	bucket := count.multiply(distance).divide(width)!.trunc()

	return new_numeric_value_from_numeric(bucket.add(new_numeric_from_string('1')))
}

// CEIL(DOUBLE PRECISION) DOUBLE PRECISION
fn func_ceil(_ FunctionContext, args []Value) !Value {
	return new_double_precision_value(math.ceil(args[0].f64_value()))
}

// CEIL(NUMERIC) NUMERIC
fn func_ceil_numeric(_ FunctionContext, args []Value) !Value {
	n := args[0].numeric_value()
	t := n.trunc()
	if !n.is_negative() && !n.equals(t) {
		return new_numeric_value_from_numeric(t.add(new_numeric_from_string('1')))
	}

	return new_numeric_value_from_numeric(t)
}

// numeric_function_type is the declared type of ABS, MOD, FLOOR, CEIL, ROUND,
// TRUNC and SIGN when
// they return an exact numeric (NUMERIC or DECIMAL), which depends on the
// declared types of the arguments.
fn numeric_function_type(name string, return_type Type, arg_types []Type) Type {
	if return_type.typ != .is_numeric && return_type.typ != .is_decimal {
		return return_type
	}

	p1, s1 := arg_types[0].exact_precision(), arg_types[0].scale

	match name {
		'ABS' {
			// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 11
			return Type{return_type.typ, p1, s1, false, false}
		}
		'MOD' {
			// The declared type is that of the divisor, which must have a scale of 0.
			// vsql also allows a scale, so the result has the larger scale of the two,
			// and it's less than the divisor (V403-01, see flag_mod_argument).
			//
			// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 12
			p2, s2 := arg_types[1].exact_precision(), arg_types[1].scale
			scale := if s1 > s2 { s1 } else { s2 }
			size := if p2 == 0 { 0 } else { p2 - s2 + scale }
			return Type{return_type.typ, size, scale, false, false}
		}
		'FLOOR', 'CEIL', 'CEILING' {
			// The precision is implementation-defined and the scale is 0. A fractional
			// part may need one more digit, such as CEIL(9.5) = 10.
			//
			// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 20.a
			size := if p1 == 0 || s1 == 0 { p1 } else { p1 - s1 + 1 }
			return Type{return_type.typ, size, 0, false, false}
		}
		'SIGN' {
			// A vsql extension (V403-04), see func_sign_numeric.
			return Type{return_type.typ, 1, 0, false, false}
		}
		'ROUND', 'TRUNC' {
			// A vsql extension (V403-02 and V403-03), see rounding_function_type.
			return rounding_function_type(name, arg_types[0], if arg_types.len == 1 {
				?i64(0)
			} else {
				none
			})
		}
		'WIDTH_BUCKET' {
			// The declared type is that of the count, which must have a scale of 0.
			//
			// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 21
			count := arg_types[3]
			return Type{count.typ, count.exact_precision(), 0, false, false}
		}
		else {
			return return_type
		}
	}
}

// with_numeric_type gives an exact numeric result of a function its declared
// type.
fn with_numeric_type(v Value, typ Type) Value {
	if v.is_null || (v.typ.typ != .is_numeric && v.typ.typ != .is_decimal) {
		return v
	}

	n := v.numeric_value()
	t := Type{v.typ.typ, typ.size, typ.scale, false, false}
	if t.typ == .is_numeric {
		return new_numeric_value_from_numeric(new_numeric(t, n.numerator, n.denominator))
	}

	return new_decimal_value_from_numeric(new_numeric(t, n.numerator, n.denominator))
}
