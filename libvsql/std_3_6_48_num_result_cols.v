module main

// ISO/IEC 9075-3:2003(E), 6.48, NumResultCols
//
// Get the number of result columns.

@[export: 'SQLNumResultCols']
fn sql_num_result_cols(statement_handle SQLInteger, column_count &i16) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// - 2.a. If there is no prepared or executed statement associated with S,
	// then an exception condition is raised: CLI-specific condition — function
	// sequence error.
	if !stmt.executed {
		return stmt.diag.error(cli_error('HY010', 'function sequence error'))
	}

	if column_count == unsafe { nil } {
		return stmt.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// - 3. ColumnCount is set to N, which is zero for a statement that isn't a
	// cursor specification.
	unsafe {
		*column_count = if cursor := stmt.cursor { i16(cursor.columns.len) } else { 0 }
	}

	return sql_success
}
