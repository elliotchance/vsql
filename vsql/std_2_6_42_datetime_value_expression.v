module vsql

import time

// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>
//
// Specify a datetime value.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2023, 4.7.4, Operations involving datetimes and intervals

type DatetimePrimary = &TimeZoneExpression | DatetimeValueFunction | ValueExpressionPrimary

fn (e DatetimePrimary) pstr(params map[string]Value) string {
	return match e {
		ValueExpressionPrimary, DatetimeValueFunction, &TimeZoneExpression {
			e.pstr(params)
		}
	}
}

fn (e DatetimePrimary) compile(mut c Compiler) !CompileResult {
	match e {
		ValueExpressionPrimary, DatetimeValueFunction, &TimeZoneExpression {
			return e.compile(mut c)!
		}
	}
}

// TimeZoneExpression is "<datetime primary> AT LOCAL", which is the datetime in
// the current default time zone displacement of the SQL-session, or
// "<datetime primary> AT TIME ZONE <interval primary>", which is the datetime
// in that time zone displacement. A value without a time zone is taken to be in
// the time zone of the SQL-session.
struct TimeZoneExpression {
	expr      DatetimePrimary
	specifier TimeZoneSpecifier
}

// TimeZoneSpecifier is LOCAL, or TIME ZONE and the interval of the time zone.
struct TimeZoneSpecifier {
	zone ?&NumericPrimary
}

fn (e TimeZoneExpression) pstr(params map[string]Value) string {
	if zone := opt_copy(e.specifier.zone) {
		return '${e.expr.pstr(params)} AT TIME ZONE ${zone.pstr(params)}'
	}

	return '${e.expr.pstr(params)} AT LOCAL'
}

// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, Syntax Rules, 1, 3, 4.a and 6
fn (e TimeZoneExpression) compile(mut c Compiler) !CompileResult {
	mut compiled := e.expr.compile(mut c)!
	compiled = c.with_type(compiled, new_type('TIMESTAMP WITH TIME ZONE', 6, 0))
	typ := match compiled.typ.typ {
		.is_time_with_time_zone, .is_time_without_time_zone {
			new_type('TIME WITH TIME ZONE', compiled.typ.size, 0)
		}
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			new_type('TIMESTAMP WITH TIME ZONE', compiled.typ.size, 0)
		}
		else {
			return sqlstate_42804('in ${e.pstr(c.params)}', 'TIME or TIMESTAMP',
				compiled.typ.str())
		}
	}

	// The time zone is an INTERVAL HOUR TO MINUTE (Syntax Rule 6).
	mut compiled_zone := ?CompileResult(none)
	if zone := opt_copy(e.specifier.zone) {
		z := c.with_type(zone.compile(mut c)!, hour_to_minute_type)
		if !z.null_parameter && (z.typ.typ != .is_interval_day_time
			|| z.typ.interval_qualifier().start != .hour
			|| z.typ.interval_qualifier().end != .minute) {
			return sqlstate_42804('in ${e.pstr(c.params)}', 'INTERVAL HOUR TO MINUTE',
				z.typ.str())
		}
		compiled_zone = z
	}

	// A datetime without a time zone gets the time zone of the session.
	//
	// ISO/IEC 9075-2:2023, 9.16, Potential sources of non-determinism, Syntax Rules, 1.i
	if !compiled.typ.has_time_zone() {
		c.check_deterministic(e.pstr(c.params))!
	}

	has_zone := if _ := opt_copy(compiled_zone) { true } else { false }
	return CompileResult{
		run:          fn [compiled, compiled_zone, has_zone, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled.run(mut conn, data, params)!
			mut zone := Value{
				is_null: true
			}
			if z := opt_copy(compiled_zone) {
				zone = z.run(mut conn, data, params)!
			}

			// The time value of a NULL isn't set, so it can't be read (it
			// crashed on Windows).
			if value.is_null || (has_zone && zone.is_null) {
				return Value{
					typ:     typ
					is_null: true
				}
			}

			mut time_zone := conn.statement_time_zone
			mut t := value.time_value()
			if has_zone {
				// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, General Rules, 2, 5.b.i.2, 5.b.ii.2.A and 5.b.ii.2.B
				minutes := zone.int_value() / 60_000_000
				if minutes < min_time_zone_displacement || minutes > max_time_zone_displacement {
					return sqlstate_22009()
				}
				t = at_time_zone(t, typ, conn.statement_time_zone)
				time_zone = i16(minutes)
			}

			return Value{
				typ: typ
				v:   InternalValue{
					time_value: box_time(at_time_zone(t, typ, time_zone))
				}
			}
		}
		typ:          typ
		contains_agg: compiled.contains_agg
	}
}

// at_time_zone is the datetime t in time_zone (in minutes), with the type typ.
// The UTC component of a datetime with a time zone stays the same, and a
// datetime without a time zone is already in time_zone. A TIME stays on the same
// (dummy) date when it moves over midnight.
//
// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, General Rules, 5.b
fn at_time_zone(t Time, typ Type, time_zone i16) Time {
	if !t.typ.has_time_zone() {
		return Time{typ, time_zone, t.t}
	}

	moved := t.t.add_seconds((int(time_zone) - int(t.time_zone)) * 60)
	if typ.typ == .is_time_with_time_zone {
		return Time{typ, time_zone, new_lenient_time(1970, 1, 1, moved.hour, moved.minute,
			moved.second, moved.nanosecond)}
	}

	return Time{typ, time_zone, moved}
}

// local_micros is the local date and time of t, as microseconds since
// 1970-01-01 00:00:00. A TIME is on 1970-01-01.
fn local_micros(t Time) i64 {
	return t.t.unix() * 1_000_000 + i64(t.t.nanosecond / 1000)
}

// time_from_micros is the Time of typ for the local date and time micros (see
// local_micros), in the time zone (in minutes).
fn time_from_micros(typ Type, time_zone i16, micros i64) Time {
	seconds := floor_div(micros, 1_000_000)
	return Time{typ, time_zone, time.unix_nanosecond(seconds, int(micros - seconds * 1_000_000) * 1000)}
}

// floor_div is x / y rounded towards negative infinity, for a positive y.
fn floor_div(x i64, y i64) i64 {
	q := x / y
	return if x % y < 0 { q - 1 } else { q }
}

// datetime_plus_interval is the datetime dt plus (or minus, when subtract is
// true) the interval iv, as the type typ. The time zone of the result is the
// time zone of dt, and its UTC component is changed. A year-month interval
// keeps the day, so it's 22008 (datetime field overflow) if that day isn't in
// the month, such as 2021-01-31 plus one month. It's also 22008 if the year
// isn't between 1 and 9999. The HOUR of a TIME is modulo 24.
//
// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, General Rules, 4, 6.a.i, 6.a.ii and 6.b
fn datetime_plus_interval(dt Value, iv Value, subtract bool, typ Type) !Value {
	t := dt.time_value()
	x := if subtract { -iv.int_value() } else { iv.int_value() }
	offset := if dt.typ.has_time_zone() { i64(t.time_zone) * 60_000_000 } else { 0 }
	mut micros := local_micros(t) - offset

	if iv.typ.typ == .is_interval_year_month {
		u := time_from_micros(typ, 0, micros).t
		months := i64(u.year) * 12 + u.month - 1 + x
		year := floor_div(months, 12)
		month := int(months - year * 12 + 1)
		if year < 1 || year > 9999 || u.day > time.days_in_month(month, int(year))! {
			return sqlstate_22008()
		}
		micros = local_micros(Time{
			t: new_lenient_time(int(year), month, u.day, u.hour, u.minute, u.second, u.nanosecond)
		})
	} else {
		micros += x
	}

	micros += offset
	if typ.typ in [.is_time_with_time_zone, .is_time_without_time_zone] {
		day := i64(86_400_000_000)
		micros = ((micros % day) + day) % day
	}

	result := time_from_micros(typ, t.time_zone, micros)
	if result.t.year < 1 || result.t.year > 9999 {
		return sqlstate_22008()
	}

	return Value{
		typ: typ
		v:   InternalValue{
			time_value: box_time(result)
		}
	}
}

// datetime_difference is "(a - b) IQ", where typ is INTERVAL IQ. Each datetime
// is converted to a number of the least significant field of IQ (such as days
// since 1970-01-01, or months since year 0), after a datetime with a time zone
// is moved to the time zone of the session (like AT LOCAL) and its time zone is
// removed. The difference of two TIMEs is less than 24 hours. The result is
// truncated to the fractional seconds precision, and it's 22015 (interval field
// overflow) if the start field has more digits than the leading field
// precision.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, General Rules, 7.a.i-7.d
fn datetime_difference(conn &Connection, a Value, b Value, typ Type) !Value {
	q := typ.interval_qualifier()
	diff := datetime_units(conn, a, q) - datetime_units(conn, b, q)
	x := match q.end {
		.year { diff * 12 }
		.month { diff }
		.second { q.truncate(diff) }
		else { diff * q.end.micros() }
	}
	q.check_leading(x)!

	return new_interval_value(typ, x)
}

// datetime_units is the datetime v as an integer in units of the least
// significant field of q (microseconds for SECOND), see datetime_difference.
//
// ISO/IEC 9075-2:2023, 6.44, <interval value expression>, General Rules, 7.c
fn datetime_units(conn &Connection, v Value, q IntervalQualifier) i64 {
	t := v.time_value()
	mut micros := local_micros(t)
	if v.typ.has_time_zone() {
		micros += (i64(conn.statement_time_zone) - i64(t.time_zone)) * 60_000_000
	}
	if v.typ.typ in [.is_time_with_time_zone, .is_time_without_time_zone] {
		day := i64(86_400_000_000)
		micros = ((micros % day) + day) % day
	}

	return match q.end {
		.year, .month {
			u := time_from_micros(v.typ, 0, micros).t
			if q.end == .year { i64(u.year) } else { i64(u.year) * 12 + u.month - 1 }
		}
		.second {
			micros
		}
		else {
			floor_div(micros, q.end.micros())
		}
	}
}
