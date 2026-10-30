module vsql

import strings

// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>
//
// Specify a comparison of two row values.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.2.2, Comparison of character strings
struct ComparisonPredicate {
	left  RowValueConstructorPredicand
	op    ComparisonOperator
	right RowValueConstructorPredicand
}

enum ComparisonOperator {
	equal
	not_equal
	less_than
	greater_than
	less_than_or_equal
	greater_than_or_equal
}

fn (op ComparisonOperator) str() string {
	return match op {
		.equal { '=' }
		.not_equal { '<>' }
		.less_than { '<' }
		.greater_than { '>' }
		.less_than_or_equal { '<=' }
		.greater_than_or_equal { '>=' }
	}
}

// truth is the result of "X <op> Y", given the comparison of X with Y. The
// operators other than = and < are defined in terms of those two by ISO/IEC
// 9075-2:2016(E), 8.2, <comparison predicate>, Syntax Rules, 6. For example,
// "X >= Y" is "Y < X OR Y = X".
fn (op ComparisonOperator) truth(cmp CompareResult) Truth {
	if cmp == .is_unknown {
		return .is_unknown
	}

	result := match op {
		.equal { cmp == .is_equal }
		.not_equal { cmp != .is_equal }
		.greater_than { cmp == .is_greater }
		.less_than { cmp == .is_less }
		.greater_than_or_equal { cmp == .is_greater || cmp == .is_equal }
		.less_than_or_equal { cmp == .is_less || cmp == .is_equal }
	}

	return if result { Truth.is_true } else { Truth.is_false }
}

fn (e ComparisonPredicate) pstr(params map[string]Value) string {
	return '${e.left.pstr(params)} ${e.op} ${e.right.pstr(params)}'
}

fn (e ComparisonPredicate) compile(mut c Compiler) !CompileResult {
	compiled_left := e.left.compile(mut c)!
	compiled_right := e.right.compile(mut c)!
	c.check_time_zone_comparison(compiled_left.typ, compiled_right.typ)!

	return CompileResult{
		run:          fn [e, compiled_left, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			mut left := compiled_left.run(mut conn, data, params)!
			mut right := compiled_right.run(mut conn, data, params)!

			return e.op.truth(compare(conn, left, right)!).value()
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_left.contains_agg || compiled_right.contains_agg
	}
}

// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, Format,
// <comparison predicate part 2>
struct ComparisonPredicatePart2 {
	op   ComparisonOperator
	expr RowValueConstructorPredicand
}

enum CompareResult as i8 {
	is_unknown = 0 // same as NULL
	is_less    = 1
	is_equal   = 2
	is_greater = 3
}

// compare() should only be used for comparison predicates (equality) but
// shouldn't be used for ordering.
//
// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 1-9
fn compare(conn &Connection, xv Value, yv Value) !CompareResult {
	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 1.a:
	// If either value is NULL the comparison is Unknown.
	if xv.is_null || yv.is_null {
		return .is_unknown
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules,
	// 1.b.i-1b.iv describe row, array, multiset and user-defined type
	// comparisons. None of those types are supported, so every comparison falls
	// under 1b.v: X = Y and X < Y are True when XV is respectively equal to, or
	// less than, YV, and False otherwise. The rest of the General Rules define
	// equal and less than for each type.

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 2
	if xv.typ.typ.is_number() && yv.typ.typ.is_number() {
		return compare_numbers(xv, yv)
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 3
	if xv.typ.typ.is_string() && yv.typ.typ.is_string() {
		return compare_strings(xv, yv)
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 4
	// and 5 compare binary strings octet by octet. Binary strings are not
	// supported.

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 6
	//
	// Datetimes are only comparable if they have the same primary datetime
	// fields (ISO/IEC 9075-2:2016(E), 4.6.2, Datetimes), so a DATE can't be
	// compared with a TIME or TIMESTAMP without a CAST.
	if xv.typ.typ.is_datetime() && yv.typ.typ.is_datetime()
		&& datetime_fields(xv.typ.typ) == datetime_fields(yv.typ.typ) {
		return compare_datetimes(conn, xv, yv)
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 7
	// compares intervals by converting both to integers of their least
	// significant field. Intervals are not supported.

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 8
	if xv.typ.typ == .is_boolean && yv.typ.typ == .is_boolean {
		return compare_booleans(xv, yv)
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 9
	// compares REF values octet by octet. Reference types are not supported.

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, Syntax Rules, 3:
	// the operands must be comparable.
	return sqlstate_42883('cannot compare ${xv.typ} and ${yv.typ}')
}

// datetime_fields describes the primary datetime fields of a datetime type,
// which is the same with or without a time zone.
fn datetime_fields(t SQLType) string {
	return match t {
		.is_date { 'DATE' }
		.is_time_with_time_zone, .is_time_without_time_zone { 'TIME' }
		else { 'TIMESTAMP' }
	}
}

// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 6: two
// datetimes are compared by the sign of the interval from subtracting them, in
// units of their least significant field (including fractional seconds).
fn compare_datetimes(conn &Connection, xv Value, yv Value) CompareResult {
	// compare_strings is only invoked when both sides are known to use
	// time_value.
	//
	// TODO(elliotchance): <primary datetime field> needs to be taken into account
	//  when it is supported.
	mut x := unsafe { xv.v.time_value }.i64()
	mut y := unsafe { yv.v.time_value }.i64()

	// Datetimes with time zones are compared after adjusting to UTC (General
	// Rule 6). If only one of them has a time zone, the other one is in the
	// time zone of the session.
	if xv.typ.has_time_zone() || yv.typ.has_time_zone() {
		_, session_time_zone := conn.now()
		x = xv.time_value().utc_micros(if xv.typ.has_time_zone() {
			xv.time_value().time_zone
		} else {
			session_time_zone
		})
		y = yv.time_value().utc_micros(if yv.typ.has_time_zone() {
			yv.time_value().time_zone
		} else {
			session_time_zone
		})
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 6.a:
	// equal when the difference is zero.
	diff := x - y
	if diff == 0 {
		return .is_equal
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 6.b:
	// less than when the difference is negative.
	if diff < 0 {
		return .is_less
	}

	return .is_greater
}

// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 2:
// numbers are compared by their algebraic value.
fn compare_numbers(xv Value, yv Value) !CompareResult {
	if (xv.typ.typ == .is_decimal || xv.typ.typ == .is_numeric)
		&& (yv.typ.typ == .is_decimal || yv.typ.typ == .is_numeric) {
		return xv.numeric_value().compare(yv.numeric_value())
	}

	// An exact number compared with an integer is compared exactly, rather than
	// as an approximate number.
	if (xv.typ.typ in [.is_decimal, .is_numeric] && yv.typ.uses_int())
		|| (xv.typ.uses_int() && yv.typ.typ in [.is_decimal, .is_numeric]) {
		return xv.as_numeric()!.compare(yv.as_numeric()!)
	}

	if (xv.typ.typ == .is_smallint || xv.typ.typ == .is_integer || xv.typ.typ == .is_bigint)
		&& (yv.typ.typ == .is_smallint || yv.typ.typ == .is_integer || yv.typ.typ == .is_bigint) {
		x := xv.int_value()
		y := yv.int_value()

		if x < y {
			return .is_less
		}

		if x > y {
			return .is_greater
		}

		return .is_equal
	}

	x := xv.as_f64()!
	y := yv.as_f64()!

	if x < y {
		return .is_less
	}

	if x > y {
		return .is_greater
	}

	return .is_equal
}

// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 3
fn compare_strings(xv Value, yv Value) CompareResult {
	// compare_strings is only invoked when both sides are known to use
	// string_value.
	mut x := unsafe { xv.v.string_value }
	mut y := unsafe { yv.v.string_value }

	// The collation is determined by 9.15, for an equality, grouping or
	// ordering operation. Only the default collation is supported, which has
	// the PAD SPACE characteristic.
	//
	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 3.a
	// ISO/IEC 9075-2:2016(E), 9.11, Equality operations, Syntax Rules, 4
	// ISO/IEC 9075-2:2016(E), 9.12, Grouping operations, Syntax Rules, 4
	// ISO/IEC 9075-2:2016(E), 9.14, Ordering operations, Syntax Rules, 4
	// ISO/IEC 9075-2:2016(E), 9.15, Collation determination, Syntax Rules, 2-4

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 3.b:
	// the shorter string is padded on the right with spaces (for a PAD SPACE
	// collation) to the length of the longer one.
	len_x := x.len
	len_y := y.len

	if len_x < len_y {
		x += strings.repeat(` `, len_y - len_x)
	} else if len_y < len_x {
		y += strings.repeat(` `, len_x - len_y)
	}

	// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 3.c:
	// the result is given by the collation. Which of several equal strings MAX,
	// MIN, DISTINCT, UNION, etc. pick is implementation-dependent (General
	// Rules, 3.d).
	if x < y {
		return .is_less
	}

	if x > y {
		return .is_greater
	}

	return .is_equal
}

// ISO/IEC 9075-2:2016(E), 8.2, <comparison predicate>, General Rules, 8: True
// is greater than False.
fn compare_booleans(xv Value, yv Value) CompareResult {
	// compare_booleans is only invoked when both sides are known to use
	// bool_value.
	x := unsafe { xv.v.bool_value }
	y := unsafe { yv.v.bool_value }

	if x == .is_true && y == .is_false {
		return .is_greater
	}

	if x == .is_false && y == .is_true {
		return .is_less
	}

	return .is_equal
}
