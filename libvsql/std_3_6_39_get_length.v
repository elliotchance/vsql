module main

// ISO/IEC 9075-3:2003(E), 6.39, GetLength
//
// Retrieve the length of the string value represented by a Large Object locator.
//
// vsql doesn't have large objects (or their locators), so a locator is never
// valid (General Rules, 5) and the rules after that are never applied (see 8.2,
// "Additional conformance requirements for SQL/CLI", Note 72). GetFunctions
// still reports that this routine isn't supported.

@[export: 'SQLGetLength']
fn sql_get_length(statement_handle SQLInteger, locator_type i16, locator SQLInteger, string_length &SQLInteger, indicator_value &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return stmt.diag.error(invalid_locator(stmt, locator_type, cli_error('HY024', 'invalid attribute value')))
}

// invalid_locator is the exception condition that GetLength, GetPosition and
// GetSubString raise:
//
// ISO/IEC 9075-3:2003(E), 6.39, GetLength, General Rules, 2, 3 and 5
// ISO/IEC 9075-3:2003(E), 6.41, GetPosition, General Rules, 2, 3 and 5
// ISO/IEC 9075-3:2003(E), 6.44, GetSubString, General Rules, 2, 3 and 5
//
// type_error is the exception condition for a LocatorType that isn't a locator
// type, which isn't the same for each routine.
fn invalid_locator(stmt &Stmt, locator_type i16, type_error IError) IError {
	// - 2. If there is a prepared statement associated with S, then an
	// exception condition is raised: CLI-specific condition — function
	// sequence error. A statement executed by ExecDirect counts too, as it
	// does for the NEST DESCRIPTOR attribute of SetStmtAttr.
	if stmt.executed || stmt.prepared != none {
		return cli_error('HY010', 'function sequence error')
	}

	// - 3. LocatorType must be CHARACTER LARGE OBJECT LOCATOR or BINARY LARGE
	// OBJECT LOCATOR.
	if locator_type != sql_clob_locator && locator_type != sql_blob_locator {
		return type_error
	}

	// - 5. If the locator isn't a valid Large Object locator, then an exception
	// condition is raised: locator exception — invalid specification. There
	// are no valid locators.
	return cli_error('0F001', 'invalid specification')
}
