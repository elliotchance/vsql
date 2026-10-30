module main

// ISO/IEC 9075-3:2003(E), 6.28, GetConnectAttr
//
// Get the value of an SQL-connection attribute.

// Codes from Table 16, "Codes used for connection attributes".
const sql_attr_auto_ipd = 10001
const sql_attr_savepoint_name = 10027

@[export: 'SQLGetConnectAttr']
fn sql_get_connect_attr(connection_handle SQLInteger, attribute SQLInteger, value voidptr, buffer_length SQLInteger, string_length &SQLInteger) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.28, GetConnectAttr, General Rules, 1
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	return get_connect_attr(mut dbc, attribute, value, buffer_length, string_length) or {
		dbc.diag.error(err)
	}
}

fn get_connect_attr(mut dbc Dbc, attribute SQLInteger, value voidptr, buffer_length SQLInteger, string_length &SQLInteger) !i16 {
	// ISO/IEC 9075-3:2003(E), 6.28, GetConnectAttr, General Rules, 2 and 3: the
	// attribute must be one of the codes in Table 16 (or AUTOCOMMIT).
	if attribute !in [sql_attr_auto_ipd, sql_attr_savepoint_name, sql_attr_autocommit] {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	// ISO/IEC 9075-3:2003(E), 4.4.3, Null pointers
	if value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// ISO/IEC 9075-3:2003(E), 6.28, GetConnectAttr, General Rules, 4: for
	// POPULATE IPD, the connection must be established. The data type of a
	// dynamic parameter isn't known until it's given a value, so the IPD is
	// never populated.
	if attribute == sql_attr_auto_ipd {
		if dbc.conn == none {
			return cli_error('08003', 'connection does not exist')
		}
		unsafe {
			*&SQLInteger(value) = sql_false
		}
		return sql_success
	}

	// AUTOCOMMIT is an implementation-defined INTEGER attribute, see
	// autocommit.v (ISO/IEC 9075-3:2003(E), 6.28, GetConnectAttr, General
	// Rules, 6.a).
	if attribute == sql_attr_autocommit {
		unsafe {
			*&SQLInteger(value) = if dbc.autocommit {
				sql_autocommit_on
			} else {
				sql_autocommit_off
			}
		}
		return sql_success
	}

	// ISO/IEC 9075-3:2003(E), 6.28, GetConnectAttr, General Rules, 5
	retrieve_string(mut dbc.diag, null_termination(dbc.env), value, dbc.savepoint_name,
		buffer_length, string_length, 4)!

	return dbc.diag.result()
}
