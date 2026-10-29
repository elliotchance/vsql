module main

import vsql

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

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.
	stmt.invoke(false) or { return stmt.diag.error(err) }
	stmt.diag.is_execute = true

	return exec_direct(mut stmt, statement_text, text_length) or { stmt.diag.error(err) }
}

fn exec_direct(mut stmt Stmt, statement_text &char, text_length SQLInteger) !i16 {
	p := preparable_statement(mut stmt, statement_text, text_length)!

	// - 10. Any prepared statement, cursor and select source associated with S
	// are destroyed.
	stmt.prepared = none
	stmt.executed = false
	stmt.close_cursor()

	// - 11, 12. P is prepared and executed. A syntax error is raised by
	// preparing it.
	mut prepared := prepare_statement(mut stmt, p)!

	return execute_statement(mut stmt, mut prepared)
}

// exec_direct_text implicitly invokes ExecDirect, for a catalog routine.
fn exec_direct_text(mut stmt Stmt, text string) !i16 {
	return exec_direct(mut stmt, &char(text.str), SQLInteger(text.len))
}

// preparable_statement is the text of a statement for ExecDirect or Prepare
// (see 6.19, "ExecDirect", General Rules 2 to 7).
fn preparable_statement(mut stmt Stmt, statement_text &char, text_length SQLInteger) !string {
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

	// - 7. If P contains a <simple comment>, then an exception condition is
	// raised: syntax error or access rule violation. The other statements that
	// aren't allowed are checked by prepare_statement.
	if contains_simple_comment(p) {
		return cli_error('42000', 'syntax error or access rule violation: -- comments are not allowed')
	}

	return p
}

// prepare_statement prepares the text of a statement for ExecDirect or Prepare,
// and sets the DYNAMIC_FUNCTION and DYNAMIC_FUNCTION_CODE that identify it.
fn prepare_statement(mut stmt Stmt, p string) !&vsql.PreparedStmt {
	mut conn := stmt_connection(stmt)!
	prepared := &vsql.PreparedStmt{
		...conn.prepare(p)!
	}
	stmt.diag.dynamic_function, stmt.diag.dynamic_function_code = prepared.command_function()

	// - 7. If P is a <start transaction statement>, a <commit statement> or a
	// <rollback statement>, then an exception condition is raised: syntax
	// error or access rule violation.
	if stmt.diag.dynamic_function in ['START TRANSACTION', 'COMMIT WORK', 'ROLLBACK WORK'] {
		return cli_error('42000', 'syntax error or access rule violation: ${stmt.diag.dynamic_function.to_lower()} can only be done with SQLStartTran or SQLEndTran')
	}

	return prepared
}

// execute_statement executes a prepared statement (for ExecDirect or
// Execute) with the values of its dynamic parameters (see 5.6, "Implicit
// EXECUTE USING and OPEN USING clauses"). If any of them are deferred, the
// first one becomes the deferred parameter number, and the statement isn't
// executed until their values are provided by ParamData and PutData.
fn execute_statement(mut stmt Stmt, mut prepared &vsql.PreparedStmt) !i16 {
	params, deferred := parameter_values(mut stmt, prepared)!
	if deferred.len > 0 {
		stmt.deferred_parameters = deferred
		stmt.deferred_params = params.clone()
		stmt.deferred_stmt = prepared
		stmt.deferred_value = none
		stmt.deferred_data_pointer = false
		return sql_need_data
	}

	return run_statement(mut stmt, mut prepared, params)
}

// run_statement executes a statement with all of its parameter values.
fn run_statement(mut stmt Stmt, mut prepared &vsql.PreparedStmt, params map[string]vsql.Value) !i16 {
	mut conn := stmt_connection(stmt)!

	// - 5.4 10. A cursor is always a copy of the result, so it can't be
	// SENSITIVE: cursor sensitivity exception — request rejected.
	if stmt.diag.dynamic_function == 'SELECT CURSOR' && stmt.cursor_sensitivity == sql_sensitive {
		return cli_error('36001', 'cursor sensitivity exception — request rejected')
	}

	if !conn.in_transaction() {
		conn.query('START TRANSACTION')!
	}
	result := prepared.query(params) or {
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
	stmt.is_query = result.msg == ''
	if stmt.is_query {
		stmt.open_cursor(result)
	}
	describe(stmt, mut conn, result.columns)

	return sql_success
}

// stmt_connection is the established SQL-connection of a statement.
fn stmt_connection(stmt &Stmt) !&vsql.Connection {
	dbc := dbcs[stmt.dbc] or { return cli_error('08003', 'connection does not exist') }

	return dbc.conn or { return cli_error('08003', 'connection does not exist') }
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
