module main

// ISO/IEC 9075-3:2003(E), 6.42, GetSessionInfo
//
// Get information about <general value specification>s supported by the
// implementation.
//
// The value is selected by an implicit ExecDirect, so it's only available for
// the <general value specification>s that vsql supports. vsql doesn't support
// any of them yet, so this always raises the syntax error from ExecDirect.

// Codes from Table 29, "Codes and data types for session implementation
// information".
const sql_current_user = 47
const sql_current_default_transform_group = 20004
const sql_current_path = 20005
const sql_current_role = 20006
const sql_session_user = 20007
const sql_system_user = 20008

const session_info = {
	sql_current_user:                    'CURRENT_USER'
	sql_current_default_transform_group: 'CURRENT_DEFAULT_TRANSFORM_GROUP'
	sql_current_path:                    'CURRENT_PATH'
	sql_current_role:                    'CURRENT_ROLE'
	sql_session_user:                    'SESSION_USER'
	sql_system_user:                     'SYSTEM_USER'
}

@[export: 'SQLGetSessionInfo']
fn sql_get_session_info(connection_handle SQLInteger, info_type i16, info_value voidptr, buffer_length i16, string_length &i16) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	return get_session_info(mut dbc, i64(connection_handle), info_type, info_value, buffer_length,
		string_length) or { dbc.diag.error(err) }
}

fn get_session_info(mut dbc Dbc, h i64, info_type i16, info_value voidptr, buffer_length i16, string_length &i16) !i16 {
	// - 2. If there is no established SQL-connection associated with C, then an
	// exception condition is raised: connection exception — connection does
	// not exist.
	if dbc.conn == none {
		return cli_error('08003', 'connection does not exist')
	}

	// - 5. If IT is not one of the codes in Table 29, then an exception
	// condition is raised: CLI-specific condition — invalid information type.
	gvs := session_info[int(info_type)] or {
		return cli_error('HY096', 'invalid information type')
	}

	// - 7 to 10. V is the value selected by an implicit ExecDirect on a
	// statement handle allocated for it. Any exception condition that it
	// raises is returned on the connection handle.
	sh := new_stmt(h)
	defer {
		free_stmt(sh)
	}
	mut stmt := stmts[sh] or { return cli_error('HY000', 'statement handle not allocated') }
	exec_direct_text(mut stmt, 'SELECT DISTINCT ${gvs} FROM INFORMATION_SCHEMA.TABLES WHERE 1 = 1')!
	cursor := stmt.cursor or { return cli_error('HY000', 'no value') }
	if stmt.rows.len == 0 {
		return cli_error('HY000', 'no value')
	}
	value := stmt.rows[0].get_column(cursor.columns[0])!

	if info_value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 11, 12. The General Rules of Subclause 5.9, "Character string
	// retrieval", are applied.
	retrieve_string(mut dbc.diag, null_termination(dbc.env), info_value, value.str(),
		buffer_length, string_length, 2)!

	return dbc.diag.result()
}
