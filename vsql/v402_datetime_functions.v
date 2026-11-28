module vsql

import math.big
import time

// The date and time functions that the SQL standard doesn't have, but other
// databases do (V402-09 to V402-12). MAKE_DATE, MAKE_TIME, MAKE_TIMESTAMP and
// MAKE_TIMESTAMPTZ build a datetime from its fields. Each field must be in the
// range of a datetime literal (see parse_timestamp_components), they never roll
// over into the next unit, except a leap second, which is the same as in a
// literal. Otherwise it's a 22007, like a CAST of a string that isn't a valid
// datetime. The result is NULL when any argument is NULL.

fn register_datetime_funcs(mut conn Connection) ! {
	// NOW() is a vsql extension (V402-01) that reads the wall clock each time
	// it's called, so unlike CURRENT_TIMESTAMP (which is fixed for the whole
	// statement) it's NOT DETERMINISTIC. That's why it can't be in a CHECK, and as
	// a function it can't be where only a datetime value function can, such as a
	// DEFAULT.
	conn.register_func(Func{'NOW', [], false, func_now, new_type('TIMESTAMP WITH TIME ZONE',
		6, 0), false, false, [vsql_now], [], false})!

	double_precision := Type{SQLType.is_double_precision, 0, 0, false, false}
	numeric := Type{SQLType.is_numeric, 0, 0, false, false}
	bigint := Type{SQLType.is_bigint, 0, 0, false, false}
	varchar := Type{SQLType.is_varchar, 0, 0, false, false}
	date := Type{SQLType.is_date, 0, 0, false, false}
	time6 := Type{SQLType.is_time_without_time_zone, 6, 0, false, false}
	timestamp6 := Type{SQLType.is_timestamp_without_time_zone, 6, 0, false, false}
	timestamptz6 := Type{SQLType.is_timestamp_with_time_zone, 6, 0, false, false}

	// Any integer is implicitly cast to a BIGINT. The seconds may have a
	// fraction, so they're a NUMERIC (an exact number) or a DOUBLE PRECISION.
	conn.register_func(Func{'MAKE_DATE', [bigint, bigint, bigint], false, func_make_date, date, false, true, [
		vsql_make_date,
	], [], false})!
	for second in [numeric, double_precision] {
		conn.register_func(Func{'MAKE_TIME', [bigint, bigint, second], false, func_make_time, time6, false, true, [
			vsql_make_time,
		], [], false})!
		conn.register_func(Func{'MAKE_TIMESTAMP', [bigint, bigint, bigint, bigint, bigint, second], false, func_make_timestamp, timestamp6, false, true, [
			vsql_make_timestamp,
		], [], false})!

		// Without a time zone it's in the session's time zone, which can change,
		// so it's not deterministic and can't be in a CHECK.
		conn.register_func(Func{'MAKE_TIMESTAMPTZ', [bigint, bigint, bigint, bigint, bigint, second], false, func_make_timestamptz, timestamptz6, false, false, [
			vsql_make_timestamptz,
		], [], false})!
		conn.register_func(Func{'MAKE_TIMESTAMPTZ', [bigint, bigint, bigint, bigint, bigint, second,
			varchar], false, func_make_timestamptz, timestamptz6, false, true, [
			vsql_make_timestamptz,
		], [], false})!
	}

	// LAST_DAY (V402-22) takes a DATE or TIMESTAMP, and a TIMESTAMP with a lower
	// precision is implicitly cast to 6.
	for source in [date, timestamp6, timestamptz6] {
		conn.register_func(Func{'LAST_DAY', [source], false, func_last_day, date, false, true, [
			vsql_last_day,
		], [], false})!
	}
}

// func_last_day is the last day of the month of a DATE or TIMESTAMP, as a DATE.
// A value WITH TIME ZONE uses the date in its own time zone, the same as a CAST
// to DATE.
fn func_last_day(_ FunctionContext, args []Value) !Value {
	t := args[0].time_value().t
	date := Type{SQLType.is_date, 0, 0, false, false}
	return Value{
		typ: date
		v:   InternalValue{
			time_value: box_time(Time{date, 0, new_lenient_time(t.year, t.month, days_in_month(t.month,
				t.year), 0, 0, 0, 0)})
		}
	}
}

fn func_make_date(_ FunctionContext, args []Value) !Value {
	return make_datetime(Type{SQLType.is_date, 0, 0, false, false}, args[0], args[1], args[2],
		none, 0)
}

fn func_make_time(_ FunctionContext, args []Value) !Value {
	return make_datetime(Type{SQLType.is_time_without_time_zone, 6, 0, false, false}, new_bigint_value(1970),
		new_bigint_value(1), new_bigint_value(1), [args[0], args[1], args[2]], 0)
}

fn func_make_timestamp(_ FunctionContext, args []Value) !Value {
	return make_datetime(Type{SQLType.is_timestamp_without_time_zone, 6, 0, false, false}, args[0],
		args[1], args[2], [args[3], args[4], args[5]], 0)
}

// func_make_timestamptz has the time zone of the session, unless there is a
// time zone argument, which is a time zone interval like in a literal (such as
// "+05:30"). Named time zones aren't supported.
fn func_make_timestamptz(ctx FunctionContext, args []Value) !Value {
	mut time_zone := i16(0)
	if args.len == 7 {
		time_zone = parse_time_zone(args[6].string_value().trim(' ')) or {
			return sqlstate_22007()
		}
	} else {
		_, time_zone = ctx.conn.now()
	}

	return make_datetime(Type{SQLType.is_timestamp_with_time_zone, 6, 0, false, false}, args[0],
		args[1], args[2], [args[3], args[4], args[5]], time_zone)
}

// make_datetime is the datetime of type typ with the date fields, and the time
// fields (hour, minute and second) if there are any, at the time zone (in
// minutes from UTC). A TIME has the date 1970-01-01, like a TIME literal (see
// new_time_from_string).
fn make_datetime(typ Type, year_value Value, month_value Value, day_value Value, time_fields ?[]Value, time_zone i16) !Value {
	year, month, day := year_value.int_value(), month_value.int_value(), day_value.int_value()
	if year < 1 || year > 9999 || month < 1 || month > 12 || day < 1
		|| day > time.days_in_month(int(month), int(year))! {
		return sqlstate_22007()
	}

	mut hour, mut minute, mut micros := i64(0), i64(0), i64(0)
	if fields := opt_copy(time_fields) {
		hour, minute = fields[0].int_value(), fields[1].int_value()
		micros = make_datetime_microseconds(fields[2])!
		if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
			return sqlstate_22007()
		}
	}

	mut t := new_lenient_time(int(year), int(month), int(day), int(hour), int(minute),
		int(micros / 1000000), int(micros % 1000000) * 1000)

	// A leap second rolls over into the next day, which a TIME wraps around to
	// the start of the same day, like a TIME literal (see new_time_from_string).
	if typ.typ == .is_time_without_time_zone {
		t = new_lenient_time(1970, 1, 1, t.hour, t.minute, t.second, t.nanosecond)
	}

	// A leap second on the last day of 9999 would be in year 10000.
	if t.year > 9999 {
		return sqlstate_22007()
	}

	return Value{
		typ: typ
		v:   InternalValue{
			time_value: box_time(Time{typ, time_zone, t})
		}
	}
}

// make_datetime_microseconds is the seconds (a NUMERIC or DOUBLE PRECISION) in
// microseconds. A fraction past 6 digits is truncated, the same as a CAST to
// TIME(6). The seconds may be 60 or 61 for a leap second, the same as in a
// literal (see parse_timestamp_components).
fn make_datetime_microseconds(second Value) !i64 {
	n := if second.typ.typ == .is_double_precision {
		new_numeric_from_f64(second.f64_value())
	} else {
		second.numeric_value()
	}

	if n.is_zero() {
		return 0
	}

	if n.is_negative() || n.integer() >= big.integer_from_int(62) {
		return sqlstate_22007()
	}

	return big_integer_to_i64(n.numerator * big.integer_from_int(1000000) / n.denominator)
}

// datetime_arg_names are the names of the parameters of the functions in this
// file (see builtin_arg_names).
const datetime_arg_names = {
	'LAST_DAY':         ['SOURCE']
	'MAKE_DATE':        ['YEARS', 'MONTHS', 'DAYS']
	'MAKE_TIME':        ['HOURS', 'MINUTES', 'SECONDS']
	'MAKE_TIMESTAMP':   ['YEARS', 'MONTHS', 'DAYS', 'HOURS', 'MINUTES', 'SECONDS']
	'MAKE_TIMESTAMPTZ': ['YEARS', 'MONTHS', 'DAYS', 'HOURS', 'MINUTES', 'SECONDS', 'TIME_ZONE']
}

fn func_now(ctx FunctionContext, _ []Value) !Value {
	return ctx.clock_timestamp()
}
