module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>
//
// Position a standing cursor on a specified row of the standing cursor's result
// set and retrieve values from that row.

// The row is returned as the result, instead of being assigned to a <fetch
// target list> (V004-03).
struct FetchStatement {
	name string
}

fn (stmt FetchStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut cursor := conn.open_cursor(stmt.name)!
	cursor.fetched = true

	// ISO/IEC 9075-2:2016(E), 15.3, Determination of the current row of a
	// cursor, General Rules 4 and 5
	if cursor.position < cursor.rows.len {
		cursor.position++
	}
	cursor.on_row = cursor.position < cursor.rows.len
	if !cursor.on_row {
		conn.add_warning(sqlstate_02000())

		return new_result(cursor.columns, []Row{}, elapsed_parse, t.elapsed())
	}

	return new_result(cursor.columns, [cursor.rows[cursor.position]], elapsed_parse,
		t.elapsed())
}

fn (stmt FetchStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN FETCH')
}
