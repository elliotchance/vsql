module main

// ISO/IEC 9075-3:2003(E), 6.47, NextResult
//
// Determine whether there are more result sets available on a statement handle
// and, if there are, initialize processing for the next result set on a
// separate statement handle.
//
// A statement only ever has one result set, so there's never a next one.

@[export: 'SQLNextResult']
fn sql_next_result(statement_handle1 SQLInteger, statement_handle2 SQLInteger) i16 {
	mut stmt1 := stmts[i64(statement_handle1)] or { return sql_invalid_handle }
	stmt1.diag.clear()
	stmt2 := stmts[i64(statement_handle2)] or { return sql_invalid_handle }
	stmt1.check_deferred() or { return stmt1.diag.error(err) }

	// - 2. If there is no executed SQL-statement associated with S1, then a
	// completion condition is raised: no data — no additional dynamic result
	// sets returned.
	if !stmt1.executed {
		return no_more_results(mut stmt1.diag)
	}

	// - 4. If there is a prepared statement associated with S2, then an
	// exception condition is raised: CLI-specific condition — function
	// sequence error.
	if stmt2.prepared != none {
		return stmt1.diag.error(cli_error('HY010', 'function sequence error'))
	}

	// - 5.b. There isn't another result set.
	return no_more_results(mut stmt1.diag)
}
