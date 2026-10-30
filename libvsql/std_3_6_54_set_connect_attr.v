module main

// ISO/IEC 9075-3:2003(E), 6.54, SetConnectAttr
//
// Set the value of an SQL-connection attribute.

@[export: 'SQLSetConnectAttr']
fn sql_set_connect_attr(connection_handle SQLInteger, attribute SQLInteger, value voidptr, string_length SQLInteger) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.54, SetConnectAttr, General Rules, 1
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	// AUTOCOMMIT is an implementation-defined INTEGER attribute, see
	// autocommit.v (ISO/IEC 9075-3:2003(E), 6.54, SetConnectAttr, General
	// Rules, 5.a).
	if attribute == sql_attr_autocommit {
		set_autocommit(mut dbc, i64(connection_handle), value) or { return dbc.diag.error(err) }
		return sql_success
	}

	// ISO/IEC 9075-3:2003(E), 6.54, SetConnectAttr, General Rules, 2 and 3: the
	// attribute must be one of the codes in Table 16 that can be set (so not
	// POPULATE IPD).
	if attribute != sql_attr_savepoint_name {
		return dbc.diag.error(cli_error('HY092', 'invalid attribute identifier'))
	}

	// ISO/IEC 9075-3:2003(E), 6.54, SetConnectAttr, General Rules, 4
	dbc.savepoint_name = input_string(unsafe { &char(value) }, i64(string_length)) or { return dbc.diag.error(err) }

	return sql_success
}
