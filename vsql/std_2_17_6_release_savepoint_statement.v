module vsql

import time

// ISO/IEC 9075-2:2023(E), 17.6, <release savepoint statement>
//
// Destroy a savepoint.

struct ReleaseSavepointStatement {
	name string
}

fn (stmt ReleaseSavepointStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// ISO/IEC 9075-2:2023(E), 17.6, <release savepoint statement>, General Rules, 1 and 3
	conn.savepoints.trim(conn.savepoint_index(stmt.name)!)

	// The changes so far can't be undone any more, so they aren't needed.
	if conn.savepoints.len == 0 {
		for _, mut catalog in conn.catalogs {
			catalog.storage.undo.recording = false
			catalog.storage.undo.entries = []UndoEntry{}
		}
	}

	return new_result_msg('RELEASE SAVEPOINT', elapsed_parse, t.elapsed())
}

fn (stmt ReleaseSavepointStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN RELEASE SAVEPOINT')
}
