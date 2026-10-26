module main

// ISO/IEC 9075-3:2003(E), 6.28, GetConnectAttr
//
// Get the value of an SQL-connection attribute.

// Codes from Table 16, "Codes used for connection attributes".
const sql_attr_auto_ipd = 10001
const sql_attr_savepoint_name = 10027

@[export: 'SQLGetConnectAttr']
fn sql_get_connect_attr(connection_handle SQLInteger, attribute SQLInteger, value voidptr, buffer_length SQLInteger, string_length &SQLInteger) i16 {
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	return get_connect_attr(mut dbc, attribute, value, buffer_length, string_length) or {
		dbc.diag.error(err)
	}
}

fn get_connect_attr(mut dbc Dbc, attribute SQLInteger, value voidptr, buffer_length SQLInteger, string_length &SQLInteger) !i16 {
	// - 3. If A is not one of the code values in Table 16, then an exception
	// condition is raised: CLI-specific condition — invalid attribute
	// identifier.
	if attribute !in [sql_attr_auto_ipd, sql_attr_savepoint_name] {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	if value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 4. If A indicates POPULATE IPD, then the connection must be
	// established. The data type of a dynamic parameter isn't known until it's
	// given a value, so the IPD is never populated.
	if attribute == sql_attr_auto_ipd {
		if dbc.conn == none {
			return cli_error('08003', 'connection does not exist')
		}
		unsafe {
			*&SQLInteger(value) = sql_false
		}
		return sql_success
	}

	// - 5. If A indicates SAVEPOINT NAME, then the General Rules of Subclause
	// 5.9, "Character string retrieval", are applied.
	retrieve_string(mut dbc.diag, null_termination(dbc.env), value, dbc.savepoint_name,
		buffer_length, string_length, 4)!

	return dbc.diag.result()
}
