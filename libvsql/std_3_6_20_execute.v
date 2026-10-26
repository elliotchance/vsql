module main

// ISO/IEC 9075-3:2003(E), 6.20, Execute
//
// Execute a prepared statement.

@[export: 'SQLExecute']
fn sql_execute(statement_handle SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.diag.is_execute = true

	return execute(mut stmt) or { stmt.diag.error(err) }
}

fn execute(mut stmt Stmt) !i16 {
	stmt.invoke(false)!

	// - 2. If there is no prepared statement associated with S, then an
	// exception condition is raised: CLI-specific condition — function sequence
	// error.
	mut prepared := stmt.prepared or { return cli_error('HY010', 'function sequence error') }
	stmt.diag.dynamic_function = stmt.prepared_function
	stmt.diag.dynamic_function_code = stmt.prepared_function_code

	// - 3. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 4 to 8. P is executed with the values of its dynamic parameters.
	stmt.executed = false

	return execute_statement(mut stmt, mut prepared)
}
