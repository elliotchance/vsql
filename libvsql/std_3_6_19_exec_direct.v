module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.19, ExecDirect
//
// Execute a statement directly.
//
// An SQL-transaction is started if one isn't active, and it must be ended with
// EndTran (see 4.1, "Introduction to SQL/CLI").
//
// The cursor of a positioned DELETE or UPDATE is found by its name when the
// statement is executed, which is an invalid cursor name if there isn't one
// (General Rules 6, 12.b.iii.1 and 12.b.iii.2). The rows of that cursor were
// copied when it was opened, so its fetched row isn't changed (General Rules
// 12.b.iii.1.C and 12.b.iii.2.C, which are implementation-defined). A prepared
// statement that references a destroyed cursor isn't destroyed (General Rules
// 10.c), which is #749.
//
// Statements that aren't a <preparable statement> (such as DECLARE CURSOR) are
// accepted (General Rules 7.a), which is #748. The data type of a dynamic
// parameter isn't determined (General Rules 7.c and 8), which is #649. There
// are no user-defined types, so there's no transform group (General Rules 9),
// and no <call statement> (General Rules 12.b.iv), which is #733. A failed
// statement still forgets the executed statement (General Rules 15), which is
// #730.

@[export: 'SQLExecDirect']
fn sql_exec_direct(statement_handle SQLInteger, statement_text &char, text_length SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
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
		...db_prepare(mut conn, p)!
	}
	stmt.diag.dynamic_function, stmt.diag.dynamic_function_code = prepared.command_function()

	// A positioned DELETE or UPDATE is a <preparable dynamic delete statement:
	// positioned> (or update), because the cursor is a dynamic cursor (of
	// another statement).
	match stmt.diag.dynamic_function_code {
		18 {
			stmt.diag.dynamic_function, stmt.diag.dynamic_function_code = 'PREPARABLE DYNAMIC DELETE CURSOR', 54
		}
		81 {
			stmt.diag.dynamic_function, stmt.diag.dynamic_function_code = 'PREPARABLE DYNAMIC UPDATE CURSOR', 55
		}
		else {}
	}

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
// executed until their values are provided by ParamData and PutData (ISO/IEC
// 9075-3:2003(E), 5.6, Implicit EXECUTE USING and OPEN USING clauses, General
// Rules, 4.q).
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

	// ISO/IEC 9075-3:2003(E), 5.4, Implicit cursor, General Rules, 10: a
	// cursor is always a copy of the result (General Rules, 8.e.i), so it can't
	// be SENSITIVE: cursor sensitivity exception — request rejected. It's
	// always INSENSITIVE, which can be guaranteed (General Rules, 9).
	if stmt.diag.dynamic_function == 'SELECT CURSOR' && stmt.cursor_sensitivity == sql_sensitive {
		return cli_error('36001', 'cursor sensitivity exception — request rejected')
	}

	if !conn.in_transaction() {
		db_query(mut conn, 'START TRANSACTION')!
		mut dbc := dbcs[stmt.dbc] or { return cli_error('08003', 'connection does not exist') }
		dbc.autocommit_transaction = dbc.autocommit
	}
	// ISO/IEC 9075-3:2003(E), 5.4, Implicit cursor, General Rules, 2 and 7:
	// the cursor of a query is also a cursor of the connection, with the
	// cursor name of S (which is generated if it doesn't have one), so that it
	// can be the cursor of a positioned DELETE or UPDATE. It's WITH HOLD if
	// CURSOR HOLDABLE is HOLDABLE (General Rules, 6). It can always be
	// scrolled, but FetchScroll checks CURSOR SCROLLABLE (General Rules, 4).
	// The dynamic parameters are replaced by their values (General Rules, 3
	// and 8.a.i), but the datetime value functions aren't evaluated at the
	// same instant (General Rules, 8.a.iii), which is #742.
	is_select := stmt.diag.dynamic_function == 'SELECT CURSOR'
	name := if is_select { normalize_cursor_name(stmt.get_cursor_name()) } else { '' }
	result := query_statement(mut prepared, name, stmt.cursor_holdable == sql_holdable,
		params) or {
		// An error that is a transaction rollback (such as a serialization
		// failure) also ends the SQL-transaction.
		if !conn.in_transaction() {
			stmt.diag.transactions_rolled_back++
		}
		autocommit(mut stmt.diag, stmt.dbc, false) or {}
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
		stmt.dynamic_cursor = name
	}
	describe(stmt, mut conn, result.columns)
	autocommit(mut stmt.diag, stmt.dbc, true)!

	return sql_success
}

// query_statement executes a statement, and opens a cursor of the connection
// with the name if it's a query (name isn't empty).
fn query_statement(mut prepared vsql.PreparedStmt, name string, hold bool, params map[string]vsql.Value) !vsql.Result {
	if name == '' {
		return db_run(mut prepared, params)
	}

	released := release()
	defer {
		reacquire(released)
	}

	return prepared.open_cursor(name, hold, params)
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
