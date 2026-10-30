module main

// ISO/IEC 9075-3:2003(E), 6.29, GetCursorName
//
// Get a cursor name.

@[export: 'SQLGetCursorName']
fn sql_get_cursor_name(statement_handle SQLInteger, cursor_name &char, buffer_length i16, name_length &i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(false) or { return stmt.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 4.4.3, Null pointers: CursorName can't be a null
	// pointer (NameLength can).
	if cursor_name == unsafe { nil } {
		return stmt.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// ISO/IEC 9075-3:2003(E), 6.29, GetCursorName, General Rules, 1 and 2: a
	// statement without a cursor name is given a unique one that starts with
	// SQL_CUR (see get_cursor_name).
	//
	// ISO/IEC 9075-3:2003(E), 6.29, GetCursorName, General Rules, 3 and 4: the
	// name is returned by ISO/IEC 9075-3:2003(E), 5.9, Character string
	// retrieval.
	retrieve_string(mut stmt.diag, stmt.null_termination(), cursor_name, stmt.get_cursor_name(),
		buffer_length, name_length, 2) or { return stmt.diag.error(err) }

	return stmt.diag.result()
}
