module main

// ISO/IEC 9075-3:2003(E), 6.19, ExecDirect
//
// Execute a statement directly.
//
// Unlike the standard, START TRANSACTION, COMMIT and ROLLBACK can be executed
// since EndTran isn't supported yet.

@[export: 'SQLExecDirect']
fn sql_exec_direct(statement_handle SQLInteger, statement_text &char, text_length SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return exec_direct(mut stmt, statement_text, text_length) or { stmt.diag.error(err) }
}

fn exec_direct(mut stmt Stmt, statement_text &char, text_length SQLInteger) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	if statement_text == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 4, 5. If L is zero, then an exception condition is raised: CLI-specific
	// condition — invalid string length or buffer length.
	p := input_string(statement_text, i64(text_length))!
	if p.len == 0 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	// - 10. Any prepared statement, cursor and select source associated with S
	// are destroyed.
	stmt.executed = false
	stmt.close_cursor()

	mut conn := dbcs[stmt.dbc] or { return cli_error('08003', 'connection does not exist') }.conn or {
		return cli_error('08003', 'connection does not exist')
	}
	result := conn.query(p)!
	stmt.executed = true

	// - 13, 14. The ROW_COUNT becomes the row count associated with S.
	stmt.row_count = row_count_of(result)

	// - 12.a. A <dynamic select statement> opens a cursor (see 5.4, "Implicit
	// cursor"). A statement that doesn't return rows has a msg instead.
	if result.msg == '' {
		stmt.cursor = result
	}

	return sql_success
}
