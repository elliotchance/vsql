module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.4, <open statement>
//
// Open a standing cursor.

struct OpenStatement {
	name string
}

fn (stmt OpenStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut cursor := conn.cursor(stmt.name)!

	// ISO/IEC 9075-2:2016(E), 15.1, Effect of opening a cursor, General Rule 2
	if cursor.is_open {
		return sqlstate_24000('cursor ${stmt.name} is already open')
	}

	if cursor.writes {
		conn.open_write_connection()!
	} else {
		conn.open_read_connection()!
	}
	defer {
		if cursor.writes {
			conn.release_write_connection()
		} else {
			conn.release_read_connection()
		}
	}

	mut plan := create_plan(cursor.query, cursor.params, mut conn)!
	cursor.rows = plan.execute([]Row{})!
	cursor.columns = plan.columns()
	cursor.is_open = true
	cursor.position = -1
	cursor.on_row = false

	return new_result_msg('OPEN', elapsed_parse, t.elapsed())
}

fn (stmt OpenStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN OPEN')
}
