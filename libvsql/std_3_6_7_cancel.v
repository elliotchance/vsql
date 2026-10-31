module main

// ISO/IEC 9075-3:2003(E), 6.7, Cancel
//
// Attempt to cancel execution of a CLI routine.
//
// libvsql isn't thread safe, so another CLI routine can't be operating on the
// statement at the same time (- 2.a). Cancel stops a statement that's waiting
// for the values of its deferred parameters (- 2.b).

@[export: 'SQLCancel']
fn sql_cancel(statement_handle SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(true) or { return stmt.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.7, Cancel, General Rules, 2.b and 2.c.i: the
	// diagnostics area is emptied, and any deferred parameter number and
	// statement source are removed.
	//
	// Routines on an SQL-environment are run one at a time, so there's never
	// a routine running on S at the same time to cancel (General Rules, 2.a).
	stmt.diag.clear()
	stmt.cancel_deferred()

	// ISO/IEC 9075-3:2003(E), 6.7, Cancel, General Rules, 2.c.ii
	return sql_success
}
