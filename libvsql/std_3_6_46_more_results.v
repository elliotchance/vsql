module main

// ISO/IEC 9075-3:2003(E), 6.46, MoreResults
//
// Determine whether there are more result sets available on a statement handle
// and, if there are, initialize processing for those result sets.
//
// A statement only ever has one result set (there's no CALL that can return
// more), so after closing the cursor there are no more.

@[export: 'SQLMoreResults']
fn sql_more_results(statement_handle SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	// - 2. If there is no executed SQL-statement associated with S, then a
	// completion condition is raised: no data — no additional dynamic result
	// sets returned.
	if !stmt.executed {
		return no_more_results(mut stmt.diag)
	}

	// - 3.b. If there is no cursor associated with S, then an exception
	// condition is raised: CLI-specific condition — function sequence error.
	if !stmt.is_query {
		return stmt.diag.error(cli_error('HY010', 'function sequence error'))
	}

	// - 4. If CR is currently open, then CR is placed in the closed state.
	stmt.close_cursor()

	// - 5.b. There isn't another result set.
	return no_more_results(mut stmt.diag)
}

// no_more_results raises a completion condition: no data — no additional
// dynamic result sets returned.
fn no_more_results(mut diag Diagnostics) i16 {
	diag.records << DiagnosticRecord{
		sqlstate: '02001'
		msg:      'no additional dynamic result sets returned'
	}

	return diag.no_data()
}
