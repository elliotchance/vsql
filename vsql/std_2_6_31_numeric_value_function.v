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
const extract_date_fields = ['YEAR', 'MONTH', 'DAY', 'DOW', 'ISODOW', 'DOY', 'WEEK', 'ISOYEAR',
	'QUARTER', 'EPOCH']

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
	if e.field !in ['TIMEZONE_HOUR', 'TIMEZONE_MINUTE', 'HOUR', 'MINUTE', 'SECOND']
		&& e.field !in extract_date_fields {
		return sqlstate_42601('EXTRACT has no field ${e.field}')
	}
	if e.field in extract_date_fields {
		expected = 'DATE or TIMESTAMP'
		allowed = [.is_date, .is_timestamp_without_time_zone, .is_timestamp_with_time_zone]
	} else if e.field in ['HOUR', 'MINUTE', 'SECOND'] {
		expected = 'TIME or TIMESTAMP'
		allowed = [.is_time_without_time_zone, .is_time_with_time_zone,
			.is_timestamp_without_time_zone, .is_timestamp_with_time_zone]
	}
	if typ.typ !in allowed {
		return sqlstate_42804('in EXTRACT(${e.field} FROM ...)', expected, typ.str())
	}

	return_type := if e.field == 'SECOND' {
		new_type('NUMERIC', typ.size + 2, i16(typ.size))
	} else if e.field == 'EPOCH' {
		new_type('NUMERIC', typ.size + 12, i16(typ.size))
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
