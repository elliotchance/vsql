module main

// ISO/IEC 9075-3:2003(E), 6.54, SetConnectAttr
//
// Set the value of an SQL-connection attribute.

@[export: 'SQLSetConnectAttr']
fn sql_set_connect_attr(connection_handle SQLInteger, attribute SQLInteger, value voidptr, string_length SQLInteger) i16 {
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	// - 3. If A is not one of the code values in Table 16, or it can't be set
	// (POPULATE IPD), then an exception condition is raised: CLI-specific
	// condition — invalid attribute identifier.
	if attribute != sql_attr_savepoint_name {
		return dbc.diag.error(cli_error('HY092', 'invalid attribute identifier'))
	}

	// - 4. The SAVEPOINT NAME attribute of C is set to the first L octets of
	// Value.
	dbc.savepoint_name = input_string(unsafe { &char(value) }, i64(string_length)) or { return dbc.diag.error(err) }

	return sql_success
}
