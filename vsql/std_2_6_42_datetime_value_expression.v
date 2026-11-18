module vsql

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
// the current default time zone displacement of the SQL-session. A value
// without a time zone is taken to be in that time zone already.
struct TimeZoneExpression {
	expr DatetimePrimary
}

fn (e TimeZoneExpression) pstr(params map[string]Value) string {
	return '${e.expr.pstr(params)} AT LOCAL'
}

// ISO/IEC 9075-2:2023, 6.42, <datetime value expression>, Syntax Rules, 1, 3 and 4.a
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

	// A datetime without a time zone gets the time zone of the session.
	//
	// ISO/IEC 9075-2:2023, 9.16, Potential sources of non-determinism, Syntax Rules, 1.i
	if !compiled.typ.has_time_zone() {
		c.check_deterministic(e.pstr(c.params))!
	}

	return CompileResult{
		run:          fn [compiled, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			value := compiled.run(mut conn, data, params)!
			if value.is_null {
				return Value{
					typ:     typ
					is_null: true
				}
			}

			return Value{
				typ: typ
				v:   InternalValue{
					time_value: box_time(at_time_zone(value.time_value(), typ, conn.statement_time_zone))
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
