module vsql

// ISO/IEC 9075-2:2016(E), 6.36, <datetime value function>
//
// Specify a function yielding a value of type datetime.

type DatetimeValueFunction = CurrentDate
	| CurrentTime
	| CurrentTimestamp
	| LocalTime
	| LocalTimestamp

fn (e DatetimeValueFunction) pstr(_ map[string]Value) string {
	return match e {
		CurrentDate { 'CURRENT_DATE' }
		CurrentTime { 'CURRENT_TIME(${e.prec})' }
		LocalTime { 'LOCALTIME(${e.prec})' }
		CurrentTimestamp { 'CURRENT_TIMESTAMP(${e.prec})' }
		LocalTimestamp { 'LOCALTIMESTAMP(${e.prec})' }
	}
}

// compile gives each function its type, and LOCALTIME and LOCALTIMESTAMP are
// CURRENT_TIME and CURRENT_TIMESTAMP without the time zone. They all return the
// statement timestamp (see set_statement_timestamp), which isn't known until
// the statement is executed, so a prepared statement has a new time each time
// it's executed.
//
// ISO/IEC 9075-2:2016(E), 6.36, <datetime value function>, Syntax Rules, 1-3
// ISO/IEC 9075-2:2016(E), 6.36, <datetime value function>, General Rules, 1-3
// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>, General Rules, 4
fn (e DatetimeValueFunction) compile(mut c Compiler) !CompileResult {
	c.check_deterministic(e.pstr(c.params))!

	match e {
		CurrentDate {
			return CompileResult{
				run:          fn (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_date_value(local_now(conn).strftime('%Y-%m-%d'))!
				}
				typ:          new_type('DATE', 0, 0)
				contains_agg: false
			}
		}
		CurrentTime {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(c.params)}: cannot have precision greater than 6')
			}

			// TODO(elliotchance): Remove this. This is a work around for a bug.
			//  https://github.com/vlang/v/issues/19748
			e2 := e

			return CompileResult{
				run:          fn [e2] (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_time_value(time_value(conn, e2.prec, true))!
				}
				typ:          new_type('TIME WITH TIME ZONE', e2.prec, 0)
				contains_agg: false
			}
		}
		CurrentTimestamp {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(c.params)}: cannot have precision greater than 6')
			}

			// TODO(elliotchance): Remove this. This is a work around for a bug.
			//  https://github.com/vlang/v/issues/19748
			e2 := e

			return CompileResult{
				run:          fn [e2] (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_timestamp_value(local_now(conn).strftime('%Y-%m-%d ') +
						time_value(conn, e2.prec, true))!
				}
				typ:          new_type('TIMESTAMP WITH TIME ZONE', e2.prec, 0)
				contains_agg: false
			}
		}
		LocalTime {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(c.params)}: cannot have precision greater than 6')
			}

			// TODO(elliotchance): Remove this. This is a work around for a bug.
			//  https://github.com/vlang/v/issues/19748
			e2 := e

			return CompileResult{
				run:          fn [e2] (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_time_value(time_value(conn, e2.prec, false))!
				}
				typ:          new_type('TIME WITHOUT TIME ZONE', e2.prec, 0)
				contains_agg: false
			}
		}
		LocalTimestamp {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(c.params)}: cannot have precision greater than 6')
			}

			// TODO(elliotchance): Remove this. This is a work around for a bug.
			//  https://github.com/vlang/v/issues/19748
			e2 := e

			return CompileResult{
				run:          fn [e2] (mut conn Connection, data Row, params map[string]Value) !Value {
					return new_timestamp_value(local_now(conn).strftime('%Y-%m-%d ') +
						time_value(conn, e2.prec, false))!
				}
				typ:          new_type('TIMESTAMP WITHOUT TIME ZONE', e2.prec, 0)
				contains_agg: false
			}
		}
	}
}

struct CurrentDate {}

struct CurrentTime {
	prec int
}

struct LocalTime {
	prec int
}

struct CurrentTimestamp {
	prec int
}

struct LocalTimestamp {
	prec int
}

fn time_value(conn &Connection, prec int, include_offset bool) string {
	now := local_now(conn)

	mut s := now.strftime('%H:%M:%S')

	if prec > 0 {
		microseconds := left_pad(int(now.nanosecond / 1000).str(), '0', 6)
		s += '.' + microseconds.substr(0, prec)
	}

	if include_offset {
		s += time_zone_str(conn.statement_time_zone)
	}

	return s
}
