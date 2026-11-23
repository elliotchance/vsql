module vsql

import time

// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>
//
// Set the current default time zone displacement for the current SQL-session.
//
// SET TIME ZONE LOCAL goes back to the time zone that the SQL-session started
// with, which is the time zone of Connection.now. SET TIME ZONE with an
// INTERVAL HOUR TO MINUTE sets the time zone displacement.

struct SetLocalTimeZoneStatement {
	value ?ValueExpression
}

// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>, Syntax Rules, 1
// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>, General Rules, 1.a, 1.b.i and 1.b.ii
fn (stmt SetLocalTimeZoneStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()
	expr := stmt.value or {
		conn.session_time_zone = none
		return new_result_msg('SET TIME ZONE', elapsed_parse, t.elapsed())
	}

	mut c := Compiler{
		conn:   conn
		params: params
	}
	compiled := c.with_type(expr.compile(mut c)!, hour_to_minute_type)
	if !compiled.null_parameter && (compiled.typ.typ != .is_interval_day_time
		|| compiled.typ.interval_qualifier().start != .hour
		|| compiled.typ.interval_qualifier().end != .minute) {
		return sqlstate_42804('in SET TIME ZONE', 'INTERVAL HOUR TO MINUTE', compiled.typ.str())
	}

	value := compiled.run(mut conn, Row{}, params)!
	minutes := value.int_value() / 60_000_000
	if value.is_null || minutes < min_time_zone_displacement || minutes > max_time_zone_displacement {
		return sqlstate_22009()
	}
	conn.session_time_zone = i16(minutes)

	return new_result_msg('SET TIME ZONE', elapsed_parse, t.elapsed())
}

fn (stmt SetLocalTimeZoneStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET TIME ZONE')
}
