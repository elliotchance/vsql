module vsql

import time

// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>
//
// Set the current default time zone displacement for the current SQL-session.
//
// SET TIME ZONE LOCAL goes back to the time zone that the SQL-session started
// with, which is the time zone of Connection.now. A time zone displacement
// (SET TIME ZONE INTERVAL '...' HOUR TO MINUTE) needs intervals (F052).

struct SetLocalTimeZoneStatement {}

// ISO/IEC 9075-2:2023, 19.4, <set local time zone statement>, General Rules, 1.a
fn (stmt SetLocalTimeZoneStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()
	conn.session_time_zone = none

	return new_result_msg('SET TIME ZONE', elapsed_parse, t.elapsed())
}

fn (stmt SetLocalTimeZoneStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET TIME ZONE')
}
