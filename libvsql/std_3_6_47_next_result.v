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
	entry := enter(sql_handle_stmt, i64(statement_handle1))
	defer {
		entry.leave()
	}
	mut stmt1 := stmts[i64(statement_handle1)] or { return sql_invalid_handle }
	stmt1.diag.clear()
	stmt2 := stmts[i64(statement_handle2)] or { return sql_invalid_handle }
	stmt1.invoke(false) or { return stmt1.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.47, NextResult, General Rules, 1 and 2: an
	// unexecuted statement has no more result sets.
	if !stmt1.executed {
		return no_more_results(mut stmt1.diag)
	}

	// ISO/IEC 9075-3:2003(E), 6.47, NextResult, General Rules, 3 and 4: the
	// second statement can't have a prepared statement.
	if stmt2.prepared != none {
		return stmt1.diag.error(cli_error('HY010', 'function sequence error'))
	}

	// ISO/IEC 9075-3:2003(E), 6.47, NextResult, General Rules, 5.b: there
	// isn't another result set.
	return no_more_results(mut stmt1.diag)
}
