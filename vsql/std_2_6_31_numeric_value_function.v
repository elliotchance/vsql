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

// new_position_expression is a <character position expression>, with the
// <char length units> of USING, or ''.
fn new_position_expression(a CharacterValueExpression, b CharacterValueExpression, using string) RoutineInvocation {
	return RoutineInvocation{
		function_name: 'POSITION'
		args:          [ValueExpression(CommonValueExpression(a)),
			ValueExpression(CommonValueExpression(b))]
		using:         using
	}
}

// new_char_length_expression is a <char length expression>, with the <char
// length units> of USING, or ''.
fn new_char_length_expression(e CharacterValueExpression, using string) RoutineInvocation {
	return RoutineInvocation{
		function_name: 'CHAR_LENGTH'
		args:          [ValueExpression(CommonValueExpression(e))]
		using:         using
	}
}

// POSITION(CHARACTER VARYING IN CHARACTER VARYING USING OCTETS) INTEGER, and
// with a CHARACTER LARGE OBJECT for either one. The position is counted in
// octets of the UTF-8 (see using_function).
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 2.b
fn func_octet_position(_ FunctionContext, args []Value) !Value {
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 2.a
	needle := args[0].string_value()
	if needle == '' {
		return new_integer_value(1)
	}

	index := args[1].string_value().index(needle) or { return new_integer_value(0) }

	return new_integer_value(index + 1)
}

// POSITION(BINARY VARYING IN BINARY VARYING) INTEGER, and with a BINARY LARGE
// OBJECT for either one. The position is counted in octets.
//
// ISO/IEC 9075-2:2023, 4.4.3.2, Other operators involving binary strings
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 3
fn func_binary_position(_ FunctionContext, args []Value) !Value {
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 3.a
	needle := args[0].string_value()
	if needle == '' {
		return new_integer_value(1)
	}

	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 3.b and 3.c
	index := args[1].string_value().index(needle) or { return new_integer_value(0) }

	return new_integer_value(index + 1)
}

// CHAR_LENGTH(CHARACTER VARYING) INTEGER
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 5.b
fn func_char_length(_ FunctionContext, args []Value) !Value {
	return new_integer_value(args[0].char_length())
}

// OCTET_LENGTH(CHARACTER VARYING) INTEGER, and for a binary string. The length
// of a large value is known without reading it.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 6
fn func_octet_length(_ FunctionContext, args []Value) !Value {
	return new_integer_value(args[0].octet_length())
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
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 10.b.v
	return approximate_value(math.sinh(args[0].f64_value()), .is_double_precision)
}

// COSH(DOUBLE PRECISION) DOUBLE PRECISION
fn func_cosh(_ FunctionContext, args []Value) !Value {
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 10.b.vii
	return approximate_value(math.cosh(args[0].f64_value()), .is_double_precision)
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

// FLOOR(SMALLINT) SMALLINT
// FLOOR(INTEGER) INTEGER
// FLOOR(BIGINT) BIGINT
// CEIL(SMALLINT) SMALLINT
// CEIL(INTEGER) INTEGER
// CEIL(BIGINT) BIGINT
//
// An integer is already rounded. The result must have the radix of the
// argument, which is binary for SMALLINT, INTEGER and BIGINT (6.1, Syntax
// Rules, 30), so it keeps the argument's type rather than being a NUMERIC.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 20.a
fn func_floor_integer(_ FunctionContext, args []Value) !Value {
	return args[0]
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
	// A DECFLOAT has the largest precision of the DECFLOAT arguments (see
	// register_decfloat_funcs).
	if return_type.typ == .is_decfloat {
		return Type{.is_decfloat, decfloat_precision(arg_types), 0, false, false}
	}

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
			// and it's less than the divisor (V403-01, see flag_mod_argument). The
			// precision is limited to the maximum precision.
			//
			// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 12
			p2, s2 := arg_types[1].exact_precision(), arg_types[1].scale
			scale := if s1 > s2 { s1 } else { s2 }
			size := if p2 == 0 { 0 } else { p2 - s2 + scale }
			return Type{return_type.typ, math.min(size, max_numeric_precision), scale, false, false}
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

// extract_date_fields are the fields of EXTRACT that a DATE or TIMESTAMP has.
// Only YEAR, MONTH and DAY are in the standard, the rest are vsql extensions:
//
//   DOW     - the day of the week, from 0 (Sunday) to 6 (Saturday).
//   ISODOW  - the ISO 8601 day of the week, from 1 (Monday) to 7 (Sunday).
//   DOY     - the day of the year, from 1 to 366.
//   WEEK    - the ISO 8601 week, from 1 to 53.
//   ISOYEAR - the ISO 8601 year that WEEK is in, which can be the year before
//             or after for a date at the start or end of a year.
//   QUARTER - the quarter of the year, from 1 to 4.
//   EPOCH   - the seconds since 1970-01-01 00:00:00 UTC. A DATE or TIMESTAMP
//             without a time zone is taken to be UTC.
//   JULIAN  - the Julian Day Number, plus the fraction of the day since local
//             midnight for a TIMESTAMP (like PostgreSQL, not the astronomical
//             Julian date, which starts at noon).
//   CENTURY, DECADE and MILLENNIUM - the year 1 is in the first century and
//             millennium, so 2001 starts the 21st century and 3rd millennium.
//             DECADE is the year divided by 10.
const extract_date_fields = ['YEAR', 'MONTH', 'DAY', 'DOW', 'ISODOW', 'DOY', 'WEEK', 'ISOYEAR',
	'QUARTER', 'EPOCH', 'JULIAN', 'CENTURY', 'DECADE', 'MILLENNIUM']

// extract_time_fields are the fields of EXTRACT that a TIME or TIMESTAMP has.
// MILLISECONDS and MICROSECONDS are vsql extensions, the whole SECOND field
// (not only its fraction) times 1000 and 1000000.
const extract_time_fields = ['HOUR', 'MINUTE', 'SECOND', 'MILLISECONDS', 'MICROSECONDS']

// extract_time_zone_fields are the fields of EXTRACT that only a value WITH
// TIME ZONE has. TIMEZONE is a vsql extension, the time zone in seconds.
const extract_time_zone_fields = ['TIMEZONE_HOUR', 'TIMEZONE_MINUTE', 'TIMEZONE']

// julian_day_1970 is the Julian Day Number of 1970-01-01.
const julian_day_1970 = 2440588

// days_from_civil is the number of days from 1970-01-01 to a date of the
// proleptic Gregorian calendar, which is negative for an earlier date.
fn days_from_civil(year int, month int, day int) int {
	y := if month <= 2 { year - 1 } else { year }
	era := (if y >= 0 { y } else { y - 399 }) / 400
	yoe := y - era * 400
	mp := if month > 2 { month - 3 } else { month + 9 }
	doy := (153 * mp + 2) / 5 + day - 1
	doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
}

// iso_day_of_week is the ISO 8601 day of the week of a day from
// days_from_civil, from 1 (Monday) to 7 (Sunday). 1970-01-01 is a Thursday.
fn iso_day_of_week(days int) int {
	return ((days + 3) % 7 + 7) % 7 + 1
}

// iso_week returns the ISO 8601 week of a date and the year that the week is
// in. A week is in the year that has its Thursday.
fn iso_week(year int, month int, day int) (int, int) {
	days := days_from_civil(year, month, day)
	thursday := days + 4 - iso_day_of_week(days)
	mut week_year := year
	if thursday < days_from_civil(year, 1, 1) {
		week_year--
	} else if thursday >= days_from_civil(year + 1, 1, 1) {
		week_year++
	}
	return (thursday - days_from_civil(week_year, 1, 1)) / 7 + 1, week_year
}

// epoch_string is whole seconds and a fraction from str_fractional_seconds
// (such as ".25", or "" for none) as a number. A negative number with a
// fraction is one second closer to zero, so -100 and .25 is -99.75.
fn epoch_string(seconds i64, fraction string) string {
	digits := fraction.trim_left('.')
	if seconds >= 0 || digits.trim_right('0') == '' {
		return '${seconds}${fraction}'
	}
	scale := u64(1) * u64(math.powi(10, digits.len))
	rest := (scale - digits.u64()).str()
	return '-${-(seconds + 1)}.${'0'.repeat(digits.len - rest.len)}${rest}'
}

// ExtractExpression is EXTRACT(field FROM source). source is a reference
// because a ValueExpression can contain an ExtractExpression, and V stores a
// sum type's value inline.
struct ExtractExpression {
	field  string
	source &ValueExpression
}

fn (e ExtractExpression) pstr(params map[string]Value) string {
	return 'EXTRACT(${e.field} FROM ${e.source.pstr(params)})'
}

// compile checks that the field is one of the fields of the source: a DATE has
// YEAR, MONTH and DAY, a TIME has HOUR, MINUTE and SECOND, a TIMESTAMP has all
// six, and only a TIME or TIMESTAMP WITH TIME ZONE has TIMEZONE_HOUR and
// TIMEZONE_MINUTE. The result is an INTEGER, except for SECOND, which is a
// NUMERIC that has the fractional seconds precision of the source as its scale.
// A time zone field has the sign of the time zone, so -05:30 is -5 hours and
// -30 minutes.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 6.a, 6.b, 7.a and 7.b
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 4.a, 4.b.i and 4.b.ii
fn (e ExtractExpression) compile(mut c Compiler) !CompileResult {
	compiled := e.source.compile(mut c)!
	typ := compiled.typ
	mut expected := 'TIME WITH TIME ZONE or TIMESTAMP WITH TIME ZONE'
	mut allowed := [SQLType.is_time_with_time_zone, .is_timestamp_with_time_zone]
	if e.field !in extract_time_zone_fields && e.field !in extract_time_fields
		&& e.field !in extract_date_fields {
		return sqlstate_42601('EXTRACT has no field ${e.field}')
	}
	if e.field in extract_date_fields {
		expected = 'DATE or TIMESTAMP'
		allowed = [.is_date, .is_timestamp_without_time_zone, .is_timestamp_with_time_zone]
	} else if e.field in extract_time_fields {
		expected = 'TIME or TIMESTAMP'
		allowed = [.is_time_without_time_zone, .is_time_with_time_zone,
			.is_timestamp_without_time_zone, .is_timestamp_with_time_zone]
	}
	// A primary datetime field of an interval (see extract_interval).
	if typ.typ.is_interval() && e.field in ['YEAR', 'MONTH', 'DAY', 'HOUR', 'MINUTE', 'SECOND'] {
		return e.compile_interval(compiled)!
	}
	if e.field in ['YEAR', 'MONTH', 'DAY', 'HOUR', 'MINUTE', 'SECOND'] {
		expected = expected.replace(' or ', ', ') + ' or INTERVAL'
	}
	if typ.typ !in allowed {
		return sqlstate_42804('in EXTRACT(${e.field} FROM ...)', expected, typ.str())
	}

	return_type := if e.field == 'SECOND' {
		new_type('NUMERIC', typ.size + 2, i16(typ.size))
	} else if e.field == 'EPOCH' {
		new_type('NUMERIC', typ.size + 12, i16(typ.size))
	} else if e.field == 'JULIAN' {
		// A DATE is a whole day. The fraction of a day of a TIMESTAMP is cut
		// to 12 places, which is enough to tell microseconds apart.
		if typ.typ == .is_date { new_type('NUMERIC', 7, 0) } else { new_type('NUMERIC', 19, 12) }
	} else if e.field == 'MILLISECONDS' {
		scale := if typ.size > 3 { typ.size - 3 } else { 0 }
		new_type('NUMERIC', 5 + scale, i16(scale))
	} else {
		new_type('INTEGER', 0, 0)
	}

	return CompileResult{
		run:          fn [e, compiled, return_type] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled.run(mut conn, data, params)!
			if value.is_null {
				return Value{
					typ:     return_type
					is_null: true
				}
			}

			t := value.time_value()
			return match e.field {
				'YEAR' {
					new_integer_value(t.t.year)
				}
				'MONTH' {
					new_integer_value(t.t.month)
				}
				'DAY' {
					new_integer_value(t.t.day)
				}
				'HOUR' {
					new_integer_value(t.t.hour)
				}
				'MINUTE' {
					new_integer_value(t.t.minute)
				}
				'SECOND' {
					seconds := '${t.t.second}${t.str_fractional_seconds(return_type.scale)}'
					with_numeric_type(new_numeric_value(seconds), return_type)
				}
				'DOW' {
					new_integer_value(iso_day_of_week(days_from_civil(t.t.year, t.t.month,
						t.t.day)) % 7)
				}
				'ISODOW' {
					new_integer_value(iso_day_of_week(days_from_civil(t.t.year, t.t.month,
						t.t.day)))
				}
				'DOY' {
					new_integer_value(days_from_civil(t.t.year, t.t.month, t.t.day) - days_from_civil(t.t.year,
						1, 1) + 1)
				}
				'WEEK' {
					week, _ := iso_week(t.t.year, t.t.month, t.t.day)
					new_integer_value(week)
				}
				'ISOYEAR' {
					_, year := iso_week(t.t.year, t.t.month, t.t.day)
					new_integer_value(year)
				}
				'QUARTER' {
					new_integer_value((t.t.month - 1) / 3 + 1)
				}
				'EPOCH' {
					seconds := i64(days_from_civil(t.t.year, t.t.month, t.t.day)) * 86400 +
						t.t.hour * 3600 + t.t.minute * 60 + t.t.second - i64(t.time_zone) * 60
					with_numeric_type(new_numeric_value(epoch_string(seconds, t.str_fractional_seconds(return_type.scale))),
						return_type)
				}
				'JULIAN' {
					day := i64(days_from_civil(t.t.year, t.t.month, t.t.day)) + julian_day_1970
					if return_type.scale == 0 {
						with_numeric_type(new_numeric_value(day.str()), return_type)
					} else {
						micros := (i64(t.t.hour) * 3600 + t.t.minute * 60 + t.t.second) * 1000000 +
							t.t.nanosecond / 1000
						// The fraction of the day to 12 places, which is
						// micros * 10^12 / (86400 * 10^6).
						fraction := micros * 1000000 / 86400
						with_numeric_type(new_numeric_value('${day}.${fraction:012}'), return_type)
					}
				}
				'CENTURY' {
					new_integer_value((t.t.year + 99) / 100)
				}
				'DECADE' {
					new_integer_value(t.t.year / 10)
				}
				'MILLENNIUM' {
					new_integer_value((t.t.year + 999) / 1000)
				}
				'MILLISECONDS' {
					micros := t.str_fractional_seconds(6)
					mut ms := '${t.t.second * 1000 + micros[1..4].int()}'
					if return_type.scale > 0 {
						ms += '.' + micros[4..4 + return_type.scale]
					}
					with_numeric_type(new_numeric_value(ms), return_type)
				}
				'MICROSECONDS' {
					new_integer_value(t.t.second * 1000000 + t.t.nanosecond / 1000)
				}
				'TIMEZONE' {
					new_integer_value(int(t.time_zone) * 60)
				}
				'TIMEZONE_HOUR' {
					new_integer_value(t.time_zone / 60)
				}
				else {
					new_integer_value(t.time_zone % 60)
				}
			}
		}
		typ:          return_type
		contains_agg: compiled.contains_agg
		constant:     compiled.constant
	}.fold()
}

// compile_interval is EXTRACT of a primary datetime field from an interval,
// which must be one of its fields. The start field is the whole number of that
// field (such as 25 for HOUR of INTERVAL '25' HOUR), and every other field is
// less than the field before it. The result has the sign of the interval. It's
// an INTEGER, except for SECOND, which is a NUMERIC with the fractional seconds
// precision of the interval as its scale.
//
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 6.a, 7.a and 7.b
// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 4.a
fn (e ExtractExpression) compile_interval(compiled CompileResult) !CompileResult {
	q := compiled.typ.interval_qualifier()
	field := interval_field_from_string(e.field)
	if int(field) < int(q.start) || int(field) > int(q.end) {
		return sqlstate_42804('in EXTRACT(${e.field} FROM ...)', 'an interval with ${e.field}',
			compiled.typ.str())
	}

	return_type := if field == .second {
		digits := if q.start == .second { q.leading_precision } else { 2 }
		new_type('NUMERIC', digits + q.fractional_precision, i16(q.fractional_precision))
	} else {
		new_type('INTEGER', 0, 0)
	}

	return CompileResult{
		run:          fn [compiled, q, field, return_type] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled.run(mut conn, data, params)!
			if value.is_null {
				return Value{
					typ:     return_type
					is_null: true
				}
			}

			return extract_interval(value.int_value(), q, field, return_type)
		}
		typ:          return_type
		contains_agg: compiled.contains_agg
		constant:     compiled.constant
	}.fold()
}

// extract_interval is the field of the interval x (a number of months or
// microseconds), see ExtractExpression.compile_interval.
fn extract_interval(x i64, q IntervalQualifier, field IntervalField, return_type Type) Value {
	if field == .year {
		return new_integer_value(int(x / 12))
	}
	if field == .month {
		return new_integer_value(int(if q.start == .month { x } else { x % 12 }))
	}

	// The microseconds of the field and every field after it.
	rest := if field == q.start {
		x
	} else {
		x % (match field {
			.hour { day_period }
			.minute { hour_period }
			else { minute_period }
		})
	}
	if field != .second {
		return new_integer_value(int(rest / field.micros()))
	}

	sign := if rest < 0 { '-' } else { '' }
	abs := if rest < 0 { -rest } else { rest }
	mut seconds := '${sign}${abs / second_period}'
	if return_type.scale > 0 {
		seconds += '.' + '${abs % second_period:06}'[..return_type.scale]
	}

	return with_numeric_type(new_numeric_value(seconds), return_type)
}

// register_numeric_value_funcs registers the <numeric value function>s that
// are called like functions.
fn register_numeric_value_funcs(mut conn Connection) ! {
	double_precision := Type{SQLType.is_double_precision, 0, 0, false, false}
	integer := Type{SQLType.is_integer, 0, 0, false, false}
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	numeric := Type{SQLType.is_numeric, 0, 0, false, false}
	smallint := Type{SQLType.is_smallint, 0, 0, false, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}
	real := Type{SQLType.is_real, 0, 0, false, false}
	decimal := Type{SQLType.is_decimal, 0, 0, false, false}
	varbinary := Type{SQLType.is_varbinary, 0, 0, false, false}
	blob := Type{SQLType.is_blob, 0, 0, false, false}
	clob := Type{SQLType.is_clob, 0, 0, false, false}

	// Scalar functions. The trigonometric functions, LOG, LN, EXP, POWER and SQRT
	// return a DOUBLE PRECISION (the approximate numeric type is
	// implementation-defined), and so do FLOOR and CEIL of an approximate number.
	// None of them are called with a NULL argument, the result is NULL.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 13.b, 14.b and 16-18
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 20.b
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, General Rules, 1.b
	conn.register_func(Func{'ABS', [double_precision], false, func_abs, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [numeric], false, func_abs_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [decimal], false, func_abs_decimal, decimal, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [smallint], false, func_abs_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [integer], false, func_abs_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [bigint], false, func_abs_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'ABS', [real], false, func_abs_real, real, false, true, [], [], false})!
	conn.register_func(Func{'ACOS', [double_precision], false, func_acos, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'ASIN', [double_precision], false, func_asin, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'ATAN', [double_precision], false, func_atan, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [double_precision], false, func_ceil, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [numeric], false, func_ceil_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [smallint], false, func_floor_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [integer], false, func_floor_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'CEIL', [bigint], false, func_floor_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [double_precision], false, func_ceil, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [numeric], false, func_ceil_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [smallint], false, func_floor_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [integer], false, func_floor_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'CEILING', [bigint], false, func_floor_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'CHARACTER_LENGTH', [varchar], false, func_char_length, integer, false, true, [], [], false})!
	conn.register_func(Func{'CHAR_LENGTH', [varchar], false, func_char_length, integer, false, true, [], [], false})!
	// POSITION, CHAR_LENGTH, OCTET_LENGTH, LOWER and UPPER of a CHARACTER LARGE
	// OBJECT are Feature T050, and OCTET_LENGTH is also T047. The length of a
	// large value is known without reading it.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Conformance Rules, 7 and 8
	// ISO/IEC 9075-2:2023, 6.33, <string value function>, Conformance Rules, 17
	conn.register_func(Func{'CHARACTER_LENGTH', [clob], false, func_char_length, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'CHAR_LENGTH', [clob], false, func_char_length, integer, false, true, ['T050'], [], false})!
	clob_octet_length := ['T047', 'T050']
	conn.register_func(Func{'OCTET_LENGTH', [clob], false, func_octet_length, integer, false, true, clob_octet_length, [], false})!
	conn.register_func(Func{'POSITION', [varchar, clob], false, func_position, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'POSITION', [clob, varchar], false, func_position, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'POSITION', [clob, clob], false, func_position, integer, false, true, ['T050'], [], false})!
	conn.register_func(Func{'COS', [double_precision], false, func_cos, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'COSH', [double_precision], false, func_cosh, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'EXP', [double_precision], false, func_exp, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [double_precision], false, func_floor, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [numeric], false, func_floor_numeric, numeric, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [smallint], false, func_floor_integer, smallint, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [integer], false, func_floor_integer, integer, false, true, [], [], false})!
	conn.register_func(Func{'FLOOR', [bigint], false, func_floor_integer, bigint, false, true, [], [], false})!
	conn.register_func(Func{'LN', [double_precision], false, func_ln, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'LOG', [double_precision, double_precision], false, func_log, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'LOG10', [double_precision], false, func_log10, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'MOD', [double_precision, double_precision], false, func_mod, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'MOD', [numeric, numeric], false, func_mod_numeric, numeric, false, true, [], [], false})!
	// The result of MOD has the type of the divisor, so there is one for each
	// combination of integer types.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 12.b
	for dividend in [smallint, integer, bigint] {
		for divisor in [smallint, integer, bigint] {
			conn.register_func(Func{'MOD', [dividend, divisor], false, func_mod_integer, divisor, false, true, [], [], false})!
		}
	}
	conn.register_func(Func{'OCTET_LENGTH', [varchar], false, func_octet_length, integer, false, true, [], [], false})!
	// A binary string (and a BINARY is a BINARY VARYING, see find_function) has
	// a length in octets, and a <binary position expression> finds one binary
	// string in another. A BINARY LARGE OBJECT needs Feature T047 for both, and
	// otherwise the <binary position expression> is T021 (either one is
	// enough).
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Conformance Rules, 6 and 8
	conn.register_func(Func{'OCTET_LENGTH', [varbinary], false, func_octet_length, integer, false, true, [], [], false})!
	conn.register_func(Func{'OCTET_LENGTH', [blob], false, func_octet_length, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POSITION', [varchar, varchar], false, func_position, integer, false, true, [], [], false})!
	conn.register_func(Func{'POSITION', [varbinary, varbinary], false, func_binary_position, integer, false, true, ['T021'], [], false})!
	conn.register_func(Func{'POSITION', [varbinary, blob], false, func_binary_position, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POSITION', [blob, varbinary], false, func_binary_position, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POSITION', [blob, blob], false, func_binary_position, integer, false, true, ['T047'], [], false})!
	conn.register_func(Func{'POWER', [double_precision, double_precision], false, func_power, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'SIN', [double_precision], false, func_sin, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'SINH', [double_precision], false, func_sinh, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'SQRT', [double_precision], false, func_sqrt, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'TAN', [double_precision], false, func_tan, double_precision, false, true, [], [], false})!
	conn.register_func(Func{'TANH', [double_precision], false, func_tanh, double_precision, false, true, [], [], false})!
	// The operand and bounds of WIDTH_BUCKET are exact (NUMERIC) or approximate
	// (DOUBLE PRECISION). The result has the type of the count, which must be an
	// exact numeric (see numeric_function_type), so there's one for each.
	//
	// ISO/IEC 9075-2:2023, 6.31, <numeric value function>, Syntax Rules, 21
	for operand in [numeric, double_precision] {
		for count in [smallint, integer, bigint, numeric] {
			conn.register_func(Func{'WIDTH_BUCKET', [operand, operand, operand, count], false, func_width_bucket, count, false, true, [], [], false})!
		}
	}
}
