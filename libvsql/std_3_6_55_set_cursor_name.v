module main

import encoding.utf8

// ISO/IEC 9075-3:2003(E), 6.55, SetCursorName
//
// Set a cursor name.
//
// A cursor name is an <identifier>, so a regular identifier is the same as its
// upper case (and two statements of a connection can't have the same name).
// vsql doesn't support positioned UPDATE and DELETE (WHERE CURRENT OF), so the
// name isn't used yet.

@[export: 'SQLSetCursorName']
fn sql_set_cursor_name(statement_handle SQLInteger, cursor_name &char, name_length i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return set_cursor_name(mut stmt, cursor_name, name_length) or { stmt.diag.error(err) }
}

fn set_cursor_name(mut stmt Stmt, cursor_name &char, name_length i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	if cursor_name == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 4, 5. If L is zero, then an exception condition is raised: CLI-specific
	// condition — invalid string length or buffer length. The octets must be
	// whole characters, otherwise an exception condition is raised: invalid
	// cursor name.
	cv := input_string(cursor_name, i64(name_length))!
	if cv.len == 0 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}
	if !utf8.validate_str(cv) {
		return cli_error('34000', 'invalid cursor name')
	}

	// - 6, 7. A name longer than 128 characters is truncated with a warning.
	mut cn := cv.trim(' ')
	if cn.runes().len > 128 {
		cn = cn.runes()[..128].string()
		stmt.diag.warning('01004', 'string data, right truncation')
	}

	// - 8, 9. CN must be an <identifier>, it can't start with SQL_CUR or
	// SQLCUR (which are the generated names), and it can't be the name of the
	// cursor of another statement of the connection, otherwise an exception
	// condition is raised: invalid cursor name.
	normalized := normalize_cursor_name(cn)
	if !is_identifier(cn) || normalized.starts_with('SQL_CUR') || normalized.starts_with('SQLCUR') {
		return cli_error('34000', 'invalid cursor name')
	}
	for h, other in stmts {
		if h != stmt.handle && other.dbc == stmt.dbc && other.cursor_name != ''
			&& normalize_cursor_name(other.cursor_name) == normalized {
			return cli_error('34000', 'invalid cursor name')
		}
	}

	// - 10. CN becomes the cursor name associated with S.
	stmt.cursor_name = cn

	return stmt.diag.result()
}

// normalize_cursor_name is the name of a cursor that a cursor name identifies:
// a delimited identifier without its quotes, or a regular identifier in upper
// case.
fn normalize_cursor_name(name string) string {
	if name.len > 1 && name.starts_with('"') && name.ends_with('"') {
		return name[1..name.len - 1].replace('""', '"')
	}

	return name.to_upper()
}
