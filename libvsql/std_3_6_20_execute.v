module main

// ISO/IEC 9075-3:2003(E), 6.20, Execute
//
// Execute a prepared statement.

@[export: 'SQLExecute']
fn sql_execute(statement_handle SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.diag.is_execute = true

	return execute(mut stmt) or { stmt.diag.error(err) }
}

fn execute(mut stmt Stmt) !i16 {
	stmt.invoke(false)!

	// ISO/IEC 9075-3:2003(E), 6.20, Execute, General Rules, 1 and 2: there must
	// be a prepared statement.
	mut prepared := stmt.prepared or { return cli_error('HY010', 'function sequence error') }
	stmt.diag.dynamic_function = stmt.prepared_function
	stmt.diag.dynamic_function_code = stmt.prepared_function_code

	// ISO/IEC 9075-3:2003(E), 6.20, Execute, General Rules, 3: there can't be
	// an open cursor.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// ISO/IEC 9075-3:2003(E), 6.20, Execute, General Rules, 4-8: P is executed
	// with the values of its dynamic parameters. The executed statement is
	// forgotten even if P fails, which is #730.
	stmt.executed = false

	return execute_statement(mut stmt, mut prepared)
}
