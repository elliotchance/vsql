module vsql

import math.big

// MAKE_INTERVAL(years, months, weeks, days, hours, mins, secs) (V402-21) builds
// an interval from numbers, like PostgreSQL's make_interval. Each argument is 0
// when it's left out, so any number of trailing arguments can be. The
// arguments are BIGINTs (any integer is implicitly cast to one), except secs,
// which may have a fraction, so it's a NUMERIC (an exact number) or a DOUBLE
// PRECISION. A fraction past microseconds is truncated.
//
// PostgreSQL has one interval type that holds months, days and microseconds
// together, but the SQL standard (and vsql) has a year-month interval and a
// day-time interval that can't be mixed. The type of the result is known when
// the statement is compiled (see make_interval_type):
//
//   - INTERVAL YEAR(8) TO MONTH when only years or months are given, or
//   - INTERVAL DAY(8) to the smallest unit that's given: INTERVAL DAY(8) for
//     weeks or days (so that it can be added to a DATE), INTERVAL DAY(8) TO
//     HOUR, INTERVAL DAY(8) TO MINUTE or INTERVAL DAY(8) TO SECOND(6). It's
//     INTERVAL DAY(8) TO SECOND(6) when nothing is given (MAKE_INTERVAL()).
//
// An argument that's a constant 0 (or NULL) isn't counted as given, so
// MAKE_INTERVAL(0, 0, 0, 3) is an INTERVAL DAY(8). Giving both a year-month
// and a day-time argument is an error. The leading field can have up to 8
// digits, otherwise it's 22015 (interval field overflow).

// make_interval_names are the parameters of MAKE_INTERVAL, which are the same as
// PostgreSQL's, so that named arguments can work the same way.
const make_interval_names = ['YEARS', 'MONTHS', 'WEEKS', 'DAYS', 'HOURS', 'MINS', 'SECS']

const make_interval_year_month = new_interval_type(IntervalQualifier{.year, .month, max_interval_leading_precision, 0})

const make_interval_day_time = new_interval_type(IntervalQualifier{.day, .second, max_interval_leading_precision, default_interval_fractional_precision})

fn register_make_interval_funcs(mut conn Connection) ! {
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}
	numeric := Type{SQLType.is_numeric, 0, 0, false, false}
	double_precision := Type{SQLType.is_double_precision, 0, 0, false, false}
	for n in 0 .. make_interval_names.len {
		conn.register_func(Func{'MAKE_INTERVAL', []Type{len: n, init: bigint}, false, func_make_interval, make_interval_day_time, false, true, [
			vsql_make_interval,
		], [], false})!
	}
	for secs in [numeric, double_precision] {
		mut arg_types := []Type{len: make_interval_names.len - 1, init: bigint}
		arg_types << secs
		conn.register_func(Func{'MAKE_INTERVAL', arg_types, false, func_make_interval, make_interval_day_time, false, true, [
			vsql_make_interval,
		], [], false})!
	}
}

// make_interval_type is the type of MAKE_INTERVAL: a year-month interval if
// only years or months are given, otherwise a day-time interval to the
// smallest unit that's given. An argument that's a constant 0 or NULL isn't
// given.
fn make_interval_type(mut c Compiler, args []CompileResult) !Type {
	mut year_month, mut day_time := false, false
	mut end := IntervalField.second
	for i, arg in args {
		if arg.constant {
			value := arg.run(mut c.conn, Row{}, c.params)!
			if value.is_null || value.as_numeric()!.is_zero() {
				continue
			}
		}

		if i < 2 {
			year_month = true
		} else {
			day_time = true
			// The weeks (2) and days (3) are DAY, the hours (4) are HOUR, etc.
			end = unsafe { IntervalField(int(IntervalField.day) + if i < 3 { 0 } else { i - 3 }) }
		}
	}

	if year_month && day_time {
		return sqlstate_42601("MAKE_INTERVAL can't have both years or months and a smaller unit, add two intervals instead")
	}

	if year_month {
		return make_interval_year_month
	}
	if !day_time {
		return make_interval_day_time
	}

	fractional_precision := if end == .second { default_interval_fractional_precision } else { 0 }
	return new_interval_type(IntervalQualifier{.day, end, max_interval_leading_precision, fractional_precision})
}

// func_make_interval is a year-month interval if the years or months aren't 0,
// otherwise a day-time interval. The type of the result is set by
// make_interval_type, which makes sure that the other arguments are 0 (so the
// value is always a whole number of the end field).
fn func_make_interval(_ FunctionContext, args []Value) !Value {
	mut fields := []big.Integer{}
	for i, arg in args {
		fields << if i == 6 {
			// The seconds, in microseconds.
			n := if arg.typ.typ == .is_double_precision {
				new_numeric_from_f64(arg.f64_value())
			} else {
				arg.numeric_value()
			}
			n.numerator * big.integer_from_int(1000000) / n.denominator
		} else {
			big.integer_from_i64(arg.int_value())
		}
	}
	for fields.len < make_interval_names.len {
		fields << big.zero_int
	}

	if fields[0].signum != 0 || fields[1].signum != 0 {
		return make_interval_value(make_interval_year_month, fields[0] * big.integer_from_int(12) +
			fields[1])
	}

	days := fields[2] * big.integer_from_int(7) + fields[3]
	minutes := (days * big.integer_from_int(24) + fields[4]) * big.integer_from_int(60) + fields[5]
	return make_interval_value(make_interval_day_time, minutes * big.integer_from_i64(60000000) +
		fields[6])
}

// make_interval_value is the interval x (in months or microseconds), which is
// 22015 (interval field overflow) if it doesn't fit in the type.
fn make_interval_value(typ Type, x big.Integer) !Value {
	q := typ.interval_qualifier()
	n := interval_from_big(x, q)!
	q.check_leading(n)!

	return new_interval_value(typ, n)
}
