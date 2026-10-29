module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.6, <close statement>
//
// Close a standing cursor.

struct CloseStatement {
	name string
}

fn (stmt CloseStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut cursor := conn.open_cursor(stmt.name)!
	cursor.close()

	return new_result_msg('CLOSE', elapsed_parse, t.elapsed())
}

fn (stmt CloseStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CLOSE')
}
