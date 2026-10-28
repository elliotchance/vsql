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
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.
	stmt.invoke(true) or { return stmt.diag.error(err) }

	// - 2.b, 2.c.i. The diagnostics area associated with S is emptied, and any
	// deferred parameter number and statement source are removed.
	stmt.diag.clear()
	stmt.cancel_deferred()

	// - 2.c.ii. A completion condition is raised: successful completion.
	return sql_success
}
