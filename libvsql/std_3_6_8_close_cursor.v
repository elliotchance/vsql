module main

// ISO/IEC 9075-3:2003(E), 6.8, CloseCursor
//
// Close a cursor.

@[export: 'SQLCloseCursor']
fn sql_close_cursor(statement_handle SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return close_cursor(mut stmt) or { stmt.diag.error(err) }
}

fn close_cursor(mut stmt Stmt) !i16 {
	// ISO/IEC 9075-3:2003(E), 6.8, CloseCursor, General Rules, 1 and 2: the
	// statement must have been executed.
	if !stmt.executed {
		return cli_error('HY010', 'function sequence error')
	}

	// ISO/IEC 9075-3:2003(E), 6.8, CloseCursor, General Rules, 3.a: the
	// statement must have an open cursor.
	if stmt.cursor == none {
		return cli_error('24000', 'invalid cursor state')
	}

	// ISO/IEC 9075-3:2003(E), 6.8, CloseCursor, General Rules, 3.b: the cursor
	// is closed and its rows (including the fetched row) are discarded.
	stmt.close_cursor()

	// If AUTOCOMMIT started the transaction and no other cursor of the
	// connection is open, the transaction is committed (see autocommit).
	autocommit(mut stmt.diag, stmt.dbc, true)!

	return sql_success
}
