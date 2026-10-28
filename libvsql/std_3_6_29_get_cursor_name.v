module main

// ISO/IEC 9075-3:2003(E), 6.29, GetCursorName
//
// Get a cursor name.

@[export: 'SQLGetCursorName']
fn sql_get_cursor_name(statement_handle SQLInteger, cursor_name &char, buffer_length i16, name_length &i16) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	if cursor_name == unsafe { nil } {
		return stmt.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// - 2. If there is no cursor name associated with S, then a unique
	// implementation-dependent name that has the prefix 'SQL_CUR' becomes the
	// cursor name associated with S.
	//
	// - 4. The name is retrieved by the General Rules of Subclause 5.9,
	// "Character string retrieval".
	retrieve_string(mut stmt.diag, stmt.null_termination(), cursor_name, stmt.get_cursor_name(),
		buffer_length, name_length, 2) or { return stmt.diag.error(err) }

	return stmt.diag.result()
}
