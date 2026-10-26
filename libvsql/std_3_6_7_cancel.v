module main

// ISO/IEC 9075-3:2003(E), 6.7, Cancel
//
// Attempt to cancel execution of a CLI routine.
//
// libvsql isn't thread safe, so another CLI routine can't be operating on the
// statement at the same time (- 2.a), and there are no deferred parameters yet
// (- 2.b). That leaves - 2.c.

@[export: 'SQLCancel']
fn sql_cancel(statement_handle SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }

	// - 2.c.i. The diagnostics area associated with S is emptied.
	stmt.diag.clear()

	// - 2.c.ii. A completion condition is raised: successful completion.
	return sql_success
}
