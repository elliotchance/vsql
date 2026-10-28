module main

// ISO/IEC 9075-3:2003(E), 6.39, GetLength
//
// Retrieve the length of the string value represented by a Large Object locator.
//
// vsql doesn't have large objects (or their locators), so this always raises an
// exception condition: CLI-specific condition — optional feature not
// implemented (see 8.2, "Additional conformance requirements for SQL/CLI",
// Note 72).

@[export: 'SQLGetLength']
fn sql_get_length(statement_handle SQLInteger, locator_type i16, locator SQLInteger, string_length &SQLInteger, indicator_value &SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.6.
	stmt.check_deferred() or { return stmt.diag.error(err) }

	return stmt.diag.error(cli_error('HYC00', 'optional feature not implemented: large object locators'))
}
