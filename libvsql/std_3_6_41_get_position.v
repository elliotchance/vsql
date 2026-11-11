module main

// ISO/IEC 9075-3:2003(E), 6.41, GetPosition
//
// Retrieve the starting position of a string value within another string value,
// where the second string value is represented by a Large Object locator.
//
// vsql doesn't have large objects (or their locators), so a locator is never
// valid (General Rules, 5) and the rules after that are never applied (see 8.2,
// "Additional conformance requirements for SQL/CLI", Note 72). GetFunctions
// still reports that this routine isn't supported.

@[export: 'SQLGetPosition']
fn sql_get_position(statement_handle SQLInteger, locator_type i16, source_locator SQLInteger, search_locator SQLInteger, search_literal &char, search_literal_length SQLInteger, from_position SQLInteger, located_at &SQLInteger, indicator_value &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	// - 3. A LocatorType that isn't a locator type is an invalid attribute
	// identifier (rather than an invalid attribute value, as it is for
	// GetLength and GetSubString).
	return stmt.diag.error(invalid_locator(stmt, locator_type, cli_error('HY092', 'invalid attribute identifier')))
}
