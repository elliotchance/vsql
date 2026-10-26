module main

// ISO/IEC 9075-3:2003(E), 6.19, ExecDirect
//
// Execute a statement directly.
//
// An SQL-transaction is started if one isn't active, and it must be ended with
// EndTran (see 4.1, "Introduction to SQL/CLI").

@[export: 'SQLExecDirect']
fn sql_exec_direct(statement_handle SQLInteger, statement_text &char, text_length SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.diag.is_execute = true

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

	stmt.diag.dynamic_function, stmt.diag.dynamic_function_code = dynamic_function(p)

	// - 7. If P is a <start transaction statement>, a <commit statement> or a
	// <rollback statement>, or it contains a <simple comment>, then an
	// exception condition is raised: syntax error or access rule violation.
	if stmt.diag.dynamic_function in ['START TRANSACTION', 'COMMIT WORK', 'ROLLBACK WORK'] {
		return cli_error('42000', 'syntax error or access rule violation: ${stmt.diag.dynamic_function.to_lower()} can only be done with SQLStartTran or SQLEndTran')
	}
	if contains_simple_comment(p) {
		return cli_error('42000', 'syntax error or access rule violation: -- comments are not allowed')
	}

	// - 10. Any prepared statement, cursor and select source associated with S
	// are destroyed.
	stmt.executed = false
	stmt.close_cursor()

	mut conn := dbcs[stmt.dbc] or { return cli_error('08003', 'connection does not exist') }.conn or {
		return cli_error('08003', 'connection does not exist')
	}
	// - 4.b, 5.4 10. A cursor is always a copy of the result, so it can't be
	// SENSITIVE: cursor sensitivity exception — request rejected.
	if stmt.diag.dynamic_function == 'SELECT CURSOR' && stmt.cursor_sensitivity == sql_sensitive {
		return cli_error('36001', 'cursor sensitivity exception — request rejected')
	}

	if !conn.in_transaction() {
		conn.query('START TRANSACTION')!
	}
	result := conn.query(p) or {
		// An error that is a transaction rollback (such as a serialization
		// failure) also ends the SQL-transaction.
		if !conn.in_transaction() {
			stmt.diag.transactions_rolled_back++
		}
		return err
	}
	stmt.executed = true

	// - 13, 14. The ROW_COUNT becomes the row count associated with S.
	stmt.row_count = row_count_of(result)
	stmt.diag.row_count = stmt.row_count

	// - 12.a. A <dynamic select statement> opens a cursor (see 5.4, "Implicit
	// cursor"). A statement that doesn't return rows has a msg instead. Either
	// way, the IRD describes its result columns (see 5.5, "Implicit DESCRIBE
	// USING clause").
	if result.msg == '' {
		stmt.cursor = result
	}
	describe(stmt, mut conn, stmt.cursor)

	return sql_success
}

// contains_simple_comment is true if text contains a <simple comment> ("--"
// until the end of the line) outside of a literal, a delimited identifier or a
// <bracketed comment> ("/* ... */", which is allowed).
fn contains_simple_comment(text string) bool {
	mut i := 0
	for i < text.len {
		if text[i] == `'` || text[i] == `"` {
			// A quote inside a literal (or identifier) is doubled, which is the
			// same as the literal ending and another one starting.
			i = (text.index_after(text[i].ascii_str(), i + 1) or { return false }) + 1
		} else if text[i..].starts_with('--') {
			return true
		} else if text[i..].starts_with('/*') {
			i = skip_bracketed_comment(text, i)
		} else {
			i++
		}
	}

	return false
}
