module main

// ISO/IEC 9075-3:2003(E), 6.7, Cancel
//
// Attempt to cancel execution of a CLI routine.
//
// Cancel stops a routine that's running on the statement on another thread
// (- 2.a), or a statement that's waiting for the values of its deferred
// parameters (- 2.b).

@[export: 'SQLCancel']
fn sql_cancel(statement_handle SQLInteger) i16 {
	// - 2.a. A routine RN is running on S. The SQL-server (vsql) always accepts
	// the request (- 2.a.iv to 2.a.vi), which cancels the SQL-statement that
	// RN is executing, if any. RN then raises HY008 operation canceled (see
	// Diagnostics.error) (- 2.a.vii). This doesn't wait for RN, and doesn't
	// change the diagnostics area of S, which belongs to RN.
	if cancel_running(i64(statement_handle)) {
		return sql_success
	}

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
	stmt.diag.clear()
	stmt.cancel_deferred()

	// ISO/IEC 9075-3:2003(E), 6.7, Cancel, General Rules, 2.c.ii
	return sql_success
}
