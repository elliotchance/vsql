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
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.46, MoreResults, General Rules, 1 and 2: an
	// unexecuted statement has no more result sets.
	if !stmt.executed {
		return no_more_results(mut stmt.diag)
	}

	// ISO/IEC 9075-3:2003(E), 6.46, MoreResults, General Rules, 3: a statement
	// without a cursor is a function sequence error (vsql has no
	// implementation-defined rules for it).
	if !stmt.is_query {
		return stmt.diag.error(cli_error('HY010', 'function sequence error'))
	}

	// ISO/IEC 9075-3:2003(E), 6.46, MoreResults, General Rules, 4: the cursor
	// is closed, and the fetched row is discarded.
	stmt.close_cursor()
	autocommit(mut stmt.diag, stmt.dbc, true) or { return stmt.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.46, MoreResults, General Rules, 5.b: there
	// isn't another result set.
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
