module main

// ISO/IEC 9075-3:2003(E), 6.44, GetSubString
//
// Either retrieve a portion of a string value that is represented by a Large
// Object locator or create a Large Object value at the server and retrieve a
// Large Object locator for that value.
//
// vsql doesn't have large objects (or their locators), so a locator is never
// valid (General Rules, 5) and the rules after that are never applied (see 8.2,
// "Additional conformance requirements for SQL/CLI", Note 72). GetFunctions
// still reports that this routine isn't supported.

@[export: 'SQLGetSubString']
fn sql_get_sub_string(statement_handle SQLInteger, locator_type i16, source_locator SQLInteger, from_position SQLInteger, for_length SQLInteger, target_type i16, target_value voidptr, buffer_length SQLInteger, string_length &SQLInteger, indicator_value &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return stmt.diag.error(invalid_locator(stmt, locator_type, cli_error('HY024', 'invalid attribute value')))
}
