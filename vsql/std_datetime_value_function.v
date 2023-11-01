module vsql

// ISO/IEC 9075-2:2016(E), 6.36, <datetime value function>
//
// # Function
//
// Specify a function yielding a value of type datetime.
//
// # Format
//~
//~ <datetime value function> /* DatetimeValueFunction */ ::=
//~     <current date value function>
//~   | <current time value function>
//~   | <current timestamp value function>
//~   | <current local time value function>
//~   | <current local timestamp value function>
//~
//~ <current date value function> /* DatetimeValueFunction */ ::=
//~     CURRENT_DATE   -> current_date
//~
//~ <current time value function> /* DatetimeValueFunction */ ::=
//~     CURRENT_TIME                                               -> current_time_1
//~   | CURRENT_TIME <left paren> <time precision> <right paren>   -> current_time_2
//~
//~ <current local time value function> /* DatetimeValueFunction */ ::=
//~     LOCALTIME                                               -> localtime_1
//~   | LOCALTIME <left paren> <time precision> <right paren>   -> localtime_2
//~
//~ <current timestamp value function> /* DatetimeValueFunction */ ::=
//~     CURRENT_TIMESTAMP                                  -> current_timestamp_1
//~   | CURRENT_TIMESTAMP
//~     <left paren> <timestamp precision> <right paren>   -> current_timestamp_2
//~
//~ <current local timestamp value function> /* DatetimeValueFunction */ ::=
//~     LOCALTIMESTAMP                                     -> localtimestamp_1
//~   | LOCALTIMESTAMP
//~     <left paren> <timestamp precision> <right paren>   -> localtimestamp_2

type DatetimeValueFunction = CurrentDate
	| CurrentTime
	| CurrentTimestamp
	| LocalTime
	| LocalTimestamp

fn (e DatetimeValueFunction) pstr(params map[string]Value) string {
	return match e {
		CurrentDate { 'CURRENT_DATE' }
		CurrentTime { 'CURRENT_TIME(${e.prec})' }
		LocalTime { 'LOCALTIME(${e.prec})' }
		CurrentTimestamp { 'CURRENT_TIMESTAMP(${e.prec})' }
		LocalTimestamp { 'LOCALTIMESTAMP(${e.prec})' }
	}
}

fn (e DatetimeValueFunction) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	match e {
		CurrentDate {
			now, _ := conn.now()

			return new_date_value(now.strftime('%Y-%m-%d'))
		}
		CurrentTime {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(params)}: cannot have precision greater than 6')
			}

			return new_time_value(time_value(conn, e.prec, true))
		}
		CurrentTimestamp {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(params)}: cannot have precision greater than 6')
			}

			now, _ := conn.now()

			return new_timestamp_value(now.strftime('%Y-%m-%d ') + time_value(conn, e.prec, true))
		}
		LocalTime {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(params)}: cannot have precision greater than 6')
			}

			return new_time_value(time_value(conn, e.prec, false))
		}
		LocalTimestamp {
			if e.prec > 6 {
				return sqlstate_42601('${DatetimeValueFunction(e).pstr(params)}: cannot have precision greater than 6')
			}

			now, _ := conn.now()

			return new_timestamp_value(now.strftime('%Y-%m-%d ') + time_value(conn, e.prec, false))
		}
	}
}

fn (e DatetimeValueFunction) eval_type(conn &Connection, data Row, params map[string]Value) !Type {
	return match e {
		CurrentDate { new_type('DATE', 0, 0) }
		CurrentTime { new_type('TIME WITH TIME ZONE', 0, 0) }
		CurrentTimestamp { new_type('TIMESTAMP WITH TIME ZONE', 0, 0) }
		LocalTime { new_type('TIME WITHOUT TIME ZONE', 0, 0) }
		LocalTimestamp { new_type('TIMESTAMP WITHOUT TIME ZONE', 0, 0) }
	}
}

fn (e DatetimeValueFunction) resolve_identifiers(conn &Connection, tables map[string]Table) !DatetimeValueFunction {
	return e
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

fn parse_current_date() !DatetimeValueFunction {
	return CurrentDate{}
}

fn parse_current_time_1() !DatetimeValueFunction {
	return CurrentTime{default_time_precision}
}

fn parse_current_time_2(prec string) !DatetimeValueFunction {
	return CurrentTime{prec.int()}
}

fn parse_localtime_1() !DatetimeValueFunction {
	return LocalTime{0}
}

fn parse_localtime_2(prec string) !DatetimeValueFunction {
	return LocalTime{prec.int()}
}

fn parse_current_timestamp_1() !DatetimeValueFunction {
	return CurrentTimestamp{default_timestamp_precision}
}

fn parse_current_timestamp_2(prec string) !DatetimeValueFunction {
	return CurrentTimestamp{prec.int()}
}

fn parse_localtimestamp_1() !DatetimeValueFunction {
	return LocalTimestamp{6}
}

fn parse_localtimestamp_2(prec string) !DatetimeValueFunction {
	return LocalTimestamp{prec.int()}
}

fn time_value(conn &Connection, prec int, include_offset bool) string {
	now, _ := conn.now()

	mut s := now.strftime('%H:%M:%S')

	if prec > 0 {
		microseconds := left_pad(int(now.nanosecond / 1000).str(), '0', 6)
		s += '.' + microseconds.substr(0, prec)
	}

	if include_offset {
		s += time_zone_value(conn)
	}

	return s
}
