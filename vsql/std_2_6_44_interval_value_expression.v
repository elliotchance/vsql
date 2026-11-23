module vsql

import math.big

// ISO/IEC 9075-2:2023, 6.44, <interval value expression>
//
// Specify an interval value.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.7.4, Operations involving datetimes and intervals
//
// The parser can't tell an interval from a number, a datetime or a character
// string, so the <plus sign>, <minus sign>, <asterisk> and <solidus> of an
// <interval value expression> and a <datetime value expression> are parsed as a
// numeric_value_expression, and the declared types of the operands decide what
// they are (see compile_datetime_arithmetic). The <sign> of an <interval factor>
// is a SignedValueExpressionPrimary. Only an <interval primary> with an
// <interval qualifier> is its own production (see IntervalQualifiedPrimary).
//
// An operand that's a datetime or an interval is flagged with F052, since it
// can only be one when it's compiled.
//
// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, Conformance Rules, 1
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Conformance Rules, 1

// is_datetime_operand is true for a datetime or an interval, which are the
// operands of datetime arithmetic.
fn is_datetime_operand(t Type) bool {
	return t.typ.is_datetime() || t.typ.is_interval()
}

// compile_datetime_arithmetic compiles "x op y" when the declared type of x or
// y is a datetime or an interval. The bool is false when neither is, and it's a
// <numeric value expression>.
//
// A dynamic parameter gets the type from 20.7, General Rules, 5.a.x and
// 5.a.xi, except that "? * i" for an interval i is a NUMERIC like "i * ?",
// rather than an interval (which can't be multiplied by an interval), and one
// added to a TIME is an INTERVAL HOUR TO SECOND rather than an INTERVAL DAY TO
// SECOND, which can't be added to a TIME (6.42, Syntax Rules, 5.a), see #1703.
//
// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, Syntax Rules, 5.a and 5.b
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Syntax Rules, 1, 2.b, 2.c, 3.a and 3.b
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.x.1, 5.a.x.2.A, 5.a.xi.1, 5.a.xi.2.A and 5.a.xi.2.B
fn (mut c Compiler) compile_datetime_arithmetic(x CompileResult, op string, y CompileResult) !(CompileResult, bool) {
	x_untyped := c.is_untyped(x)
	y_untyped := c.is_untyped(y)
	if !((!x_untyped && is_datetime_operand(x.typ)) || (!y_untyped && is_datetime_operand(y.typ))) {
		return x, false
	}

	mut left := x
	mut right := y
	if x_untyped {
		left = c.with_type(x, datetime_parameter_type(op, y.typ, true))
	}
	if y_untyped {
		right = c.with_type(y, datetime_parameter_type(op, x.typ, false))
	}
	if c.conn.flagging {
		c.conn.flagged_features << 'F052'
	}

	l := left.typ
	r := right.typ
	not_exist := sqlstate_42883('operator does not exist: ${l} ${op} ${r}')
	typ := match op {
		'+', '-' {
			if l.typ.is_datetime() && r.typ.is_interval() {
				datetime_plus_interval_type(l, r) or { return not_exist }
			} else if op == '+' && l.typ.is_interval() && r.typ.is_datetime() {
				datetime_plus_interval_type(r, l) or { return not_exist }
			} else if l.typ.is_interval() && l.typ == r.typ {
				combine_interval_types(l, r, max_interval_leading_precision)
			} else if op == '-' && l.typ.is_datetime() && r.typ.is_datetime() {
				return sqlstate_42601('${l} - ${r} needs an interval qualifier, such as (A - B) DAY TO SECOND')
			} else {
				return not_exist
			}
		}
		else {
			// * or /
			if l.typ.is_interval() && r.typ.is_number() {
				with_leading_precision(l, max_interval_leading_precision)
			} else if op == '*' && l.typ.is_number() && r.typ.is_interval() {
				with_leading_precision(r, max_interval_leading_precision)
			} else {
				return not_exist
			}
		}
	}

	// A datetime without a time zone that's added to a datetime with a time zone
	// can't happen (the other operand is always an interval), so the result
	// only depends on the operands.
	return CompileResult{
		run:          fn [left, op, right, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			a := left.run(mut conn, data, params)!
			b := right.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, General Rules, 1
			// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, General Rules, 2
			if a.is_null || b.is_null {
				return Value{
					typ:     typ
					is_null: true
				}
			}

			return eval_datetime_arithmetic(a, op, b, typ)!
		}
		typ:          typ
		contains_agg: left.contains_agg || right.contains_agg
		constant:     left.constant && right.constant
	}.fold(), true
}

// datetime_parameter_type is the type of a dynamic parameter that's an operand
// of op, where other is the declared type of the other operand, and is_x is
// true when the dynamic parameter is the left operand.
//
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.x and 5.a.xi
fn datetime_parameter_type(op string, other Type, is_x bool) Type {
	if op in ['*', '/'] {
		return Type{.is_numeric, max_numeric_precision, 0, false, false}
	}

	if op == '-' && is_x {
		return other
	}

	return match other.typ {
		.is_date {
			new_interval_type(IntervalQualifier{.year, .month, max_interval_leading_precision, 0})
		}
		.is_time_with_time_zone, .is_time_without_time_zone {
			new_interval_type(IntervalQualifier{.hour, .second, max_interval_leading_precision, 6})
		}
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			new_interval_type(IntervalQualifier{.day, .second, max_interval_leading_precision, 6})
		}
		else {
			other
		}
	}
}

// datetime_plus_interval_type is the declared type of a datetime plus or minus
// an interval: the type of the datetime, with the greater fractional seconds
// precision. The interval can only have the fields of the datetime (a DATE has
// YEAR, MONTH and DAY, and a TIME has HOUR, MINUTE and SECOND).
//
// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, Syntax Rules, 5.a and 5.b
fn datetime_plus_interval_type(datetime Type, interval Type) ?Type {
	q := interval.interval_qualifier()
	ok := match datetime.typ {
		.is_date {
			int(q.end) <= int(IntervalField.day)
		}
		.is_time_with_time_zone, .is_time_without_time_zone {
			int(q.start) >= int(IntervalField.hour)
		}
		else {
			true
		}
	}
	if !ok {
		return none
	}

	if datetime.typ == .is_date {
		return Type{.is_date, 0, 0, false, false}
	}

	precision := if q.end == .second && q.fractional_precision > datetime.size {
		q.fractional_precision
	} else {
		datetime.size
	}

	return Type{datetime.typ, precision, 0, false, false}
}

// combine_interval_types is the interval type with every field of a and b, the
// greater fractional seconds precision, and the leading field precision.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Syntax Rules, 2.c
// ISO/IEC 9075-2:2023, 9.5, Result of data type combinations, Syntax Rules, 3.e
fn combine_interval_types(a Type, b Type, leading_precision int) Type {
	qa := a.interval_qualifier()
	qb := b.interval_qualifier()
	start := if int(qa.start) < int(qb.start) { qa.start } else { qb.start }
	end := if int(qa.end) > int(qb.end) { qa.end } else { qb.end }
	fractional := if qa.end == .second && qb.end == .second {
		if qa.fractional_precision > qb.fractional_precision {
			qa.fractional_precision
		} else {
			qb.fractional_precision
		}
	} else if qa.end == .second {
		qa.fractional_precision
	} else {
		qb.fractional_precision
	}

	return new_interval_type(IntervalQualifier{start, end, leading_precision, if end == .second {
		fractional
	} else {
		0
	}})
}

// with_leading_precision is the interval type t with another leading field
// precision. The leading field precision of the result of an interval
// operation is implementation-defined (IV157), and it's the maximum so that
// the result doesn't overflow.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Syntax Rules, 2.b
fn with_leading_precision(t Type, leading_precision int) Type {
	q := t.interval_qualifier()
	return new_interval_type(IntervalQualifier{q.start, q.end, leading_precision, q.fractional_precision})
}

// eval_datetime_arithmetic is "a op b", for operands that aren't NULL, where
// typ is the declared type of the result (see compile_datetime_arithmetic).
fn eval_datetime_arithmetic(a Value, op string, b Value, typ Type) !Value {
	if a.typ.typ.is_datetime() {
		return datetime_plus_interval(a, b, op == '-', typ)!
	}
	if b.typ.typ.is_datetime() {
		return datetime_plus_interval(b, a, false, typ)!
	}

	q := typ.interval_qualifier()
	x := match op {
		'+' { add_intervals(a.int_value(), b.int_value())! }
		'-' { add_intervals(a.int_value(), -b.int_value())! }
		'*' {
			multiply_interval(if a.typ.typ.is_interval() { a } else { b }, if a.typ.typ.is_interval() {
				b
			} else {
				a
			}, q)!
		}
		else { divide_interval(a, b, q)! }
	}
	q.check_leading(x)!

	return new_interval_value(typ, x)
}

// add_intervals is x + y, which are the values of two intervals of the same
// class. It's 22015 (interval field overflow) if it doesn't fit.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, General Rules, 6
fn add_intervals(x i64, y i64) !i64 {
	z := x + y
	if (x > 0 && y > 0 && z < 0) || (x < 0 && y < 0 && z >= 0) {
		return sqlstate_22015()
	}

	return z
}

// multiply_interval is the interval i times the number n, in the units of the
// least significant field of q (an exact multiple of them), truncated towards
// zero.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, General Rules, 1, 5.a-5.f
fn multiply_interval(i Value, n Value, q IntervalQualifier) !i64 {
	factor := n.as_numeric()!
	product := big.integer_from_i64(i.int_value()) * factor.numerator / factor.denominator

	return interval_from_big(product, q)!
}

// divide_interval is the interval i divided by the number n, see
// multiply_interval. A divisor of zero is 22012 (division by zero).
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, General Rules, 5.a-5.f
fn divide_interval(i Value, n Value, q IntervalQualifier) !i64 {
	divisor := n.as_numeric()!
	if divisor.is_zero() {
		return sqlstate_22012()
	}
	quotient := big.integer_from_i64(i.int_value()) * divisor.denominator / divisor.numerator

	return interval_from_big(quotient, q)!
}

// interval_from_big truncates x to the least significant field of q. It's 22015
// (interval field overflow) if it doesn't fit in an interval.
fn interval_from_big(x big.Integer, q IntervalQualifier) !i64 {
	if x.abs() > big.integer_from_i64(max_i64) {
		return sqlstate_22015()
	}

	return q.truncate(big_integer_to_i64(x))
}

// IntervalQualifiedPrimary is an <interval primary> with an <interval
// qualifier>, which can be a dynamic parameter (such as "? DAY") or the
// difference of two datetimes (such as "(a - b) DAY TO SECOND"). expr is a
// reference because a NumericPrimary can contain one, and V stores a sum type's
// value inline.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Format
struct IntervalQualifiedPrimary {
	expr      &ValueExpressionPrimary
	qualifier IntervalQualifier
}

fn new_interval_qualified_primary(expr ValueExpressionPrimary, qualifier IntervalQualifier) IntervalQualifiedPrimary {
	return IntervalQualifiedPrimary{&expr, qualifier}
}

fn (e IntervalQualifiedPrimary) pstr(params map[string]Value) string {
	return '${e.expr.pstr(params)} ${e.qualifier}'
}

// compile is CAST(? AS INTERVAL IQ) for a dynamic parameter. Otherwise, it
// must be the difference of two datetimes, in parentheses.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Syntax Rules, 2.a, 4 and 5
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, General Rules, 3.a
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.i
fn (e IntervalQualifiedPrimary) compile(mut c Compiler) !CompileResult {
	typ := new_interval_type(e.qualifier)
	expr := *e.expr
	if expr is NonparenthesizedValueExpressionPrimary {
		if expr is ValueSpecification {
			if expr is GeneralValueSpecification {
				if expr is DynamicParameterSpecification {
					operand := ValueExpression(CommonValueExpression(DatetimePrimary(expr)))
					return new_cast_specification(CastOperand(operand), typ).compile(mut c)!
				}
			}
		}
	}

	if expr is ParenthesizedValueExpression {
		inner := *expr.e
		if inner is CommonValueExpression {
			if inner is NumericValueExpression {
				if n := inner.n {
					if inner.op == '-' {
						return c.compile_datetime_difference(n.compile(mut c)!, inner.term.compile(mut c)!,
							typ)!
					}
				}
			}
		}
	}

	return sqlstate_42601('an interval qualifier can only follow a dynamic parameter or the difference of two datetimes in parentheses: ${e.pstr(c.params)}')
}

// compile_datetime_difference compiles "(x - y) IQ", where typ is INTERVAL IQ.
// The datetimes must be comparable, and the difference of a datetime with a
// time zone and one without is possibly non-deterministic, since the one
// without a time zone is in the time zone of the session.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, Syntax Rules, 4
// ISO/IEC 9075-2:2023, 9.16, Potential sources of non-determinism, Syntax Rules, 1.k
// ISO/IEC 9075-2:2023, 20.7, <prepare statement>, General Rules, 5.a.xi.1
fn (mut c Compiler) compile_datetime_difference(x CompileResult, y CompileResult, typ Type) !CompileResult {
	mut left := x
	mut right := y
	if c.is_untyped(left) && !c.is_untyped(right) {
		left = c.with_type(left, right.typ)
	}
	if c.is_untyped(right) && !c.is_untyped(left) {
		right = c.with_type(right, left.typ)
	}
	if !left.typ.typ.is_datetime() || !right.typ.typ.is_datetime()
		|| datetime_fields(left.typ.typ) != datetime_fields(right.typ.typ) {
		return sqlstate_42883('operator does not exist: (${left.typ} - ${right.typ}) ${typ.interval_qualifier()}')
	}
	if left.typ.has_time_zone() != right.typ.has_time_zone() {
		c.check_deterministic('the difference of ${left.typ} and ${right.typ}')!
	}

	return CompileResult{
		run:          fn [left, right, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			a := left.run(mut conn, data, params)!
			b := right.run(mut conn, data, params)!
			if a.is_null || b.is_null {
				return Value{
					typ:     typ
					is_null: true
				}
			}

			return datetime_difference(conn, a, b, typ)!
		}
		typ:          typ
		contains_agg: left.contains_agg || right.contains_agg
		// A datetime with a time zone is in the time zone of the session first,
		// which can change.
		constant:     left.constant && right.constant && !left.typ.has_time_zone()
			&& !right.typ.has_time_zone()
	}.fold()
}
