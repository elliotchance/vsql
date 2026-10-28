module main

// ISO/IEC 9075-3:2003(E), 6.8, CloseCursor
//
// Close a cursor.

@[export: 'SQLCloseCursor']
fn sql_close_cursor(statement_handle SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.6.
	stmt.check_deferred() or { return stmt.diag.error(err) }

	return close_cursor(mut stmt) or { stmt.diag.error(err) }
}

fn close_cursor(mut stmt Stmt) !i16 {
	// - 2. If there is no executed statement associated with S, then an
	// exception condition is raised: CLI-specific condition — function sequence
	// error.
	if !stmt.executed {
		return cli_error('HY010', 'function sequence error')
	}

	// - 3.a. If there is no open cursor associated with S, then an exception
	// condition is raised: invalid cursor state.
	if stmt.cursor == none {
		return cli_error('24000', 'invalid cursor state')
	}

	stmt.close_cursor()

	return sql_success
}
