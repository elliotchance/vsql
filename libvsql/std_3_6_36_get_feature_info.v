module main

// ISO/IEC 9075-3:2003, 6.36, GetFeatureInfo
//
// Get information about features supported by the CLI implementation.
//
// Whether a feature or subfeature is supported is selected from the
// SQL_FEATURES view of the INFORMATION_SCHEMA by an implicit ExecDirect (General
// Rules, 13 to 16), like the standard. The view is built from the
// docs/sql-compliance-9075-*.rst pages. There are no packages.

@[export: 'SQLGetFeatureInfo']
fn sql_get_feature_info(connection_handle SQLInteger, feature_type &char, feature_type_length i16, feature_id &char, feature_id_length i16, sub_feature_id &char, sub_feature_id_length i16, supported &i16) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	return get_feature_info(mut dbc, feature_type, feature_type_length, feature_id,
		feature_id_length, sub_feature_id, sub_feature_id_length, supported) or {
		dbc.diag.error(err)
	}
}

fn get_feature_info(mut dbc Dbc, feature_type &char, feature_type_length i16, feature_id &char, feature_id_length i16, sub_feature_id &char, sub_feature_id_length i16, supported &i16) !i16 {
	// - 2. If there is no established SQL-connection associated with C, then an
	// exception condition is raised: connection exception — connection does
	// not exist.
	if dbc.conn == none {
		return cli_error('08003', 'connection does not exist')
	}

	// - 3. If EC is not the current SQL-connection, then the General Rules of
	// Subclause 5.3, "Implicit set connection", are applied to EC as the
	// dormant SQL-connection.
	implicit_set_connection(dbc.handle)!

	// - 4 to 11. The arguments, which can't be zero-length strings.
	ft := feature_info_arg(feature_type, feature_type_length)!
	if ft !in ['FEATURE', 'SUBFEATURE', 'PACKAGE'] {
		return cli_error('HY024', 'invalid attribute value')
	}
	fi := feature_info_arg(feature_id, feature_id_length)!
	// A feature's SUB_FEATURE_ID is a single space. A subfeature ID that's
	// trimmed to a zero-length string isn't a subfeature, even though it's equal
	// to a single space (PAD SPACE).
	sfi := if ft == 'SUBFEATURE' {
		feature_info_arg(sub_feature_id, sub_feature_id_length)!
	} else {
		' '
	}
	if ft == 'PACKAGE' || sfi == '' {
		return cli_error('HY024', 'invalid attribute value')
	}

	// - 13 to 16. IS is selected by an implicit ExecDirect on a statement handle
	// allocated for it. Any exception condition that it raises is returned on
	// the connection handle. The view doesn't have the
	// FEATURE_SUBFEATURE_PACKAGE_CODE column (of the 2003 edition), so the type
	// is the SUB_FEATURE_ID.
	sh := new_stmt(dbc.handle)
	defer {
		free_stmt(sh)
	}
	mut stmt := stmts[sh] or { return cli_error('HY000', 'statement handle not allocated') }
	exec_direct_text(mut stmt, 'SELECT IS_SUPPORTED FROM INFORMATION_SCHEMA.SQL_FEATURES WHERE FEATURE_ID = ${sql_string(fi)} AND SUB_FEATURE_ID = ${sql_string(sfi)}')!

	// - 12. If there is no such feature, then an exception condition is
	// raised: CLI-specific condition — invalid attribute value.
	cursor := stmt.cursor or { return cli_error('HY000', 'no value') }
	if stmt.rows.len == 0 {
		return cli_error('HY024', 'invalid attribute value')
	}
	is_supported := stmt.rows[0].get_column(cursor.columns[0])!.string_value() == 'YES'

	if supported == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 17. If the value of IS is 'YES', then Supported is set to 1 (one);
	// otherwise, Supported is set to 0 (zero).
	unsafe {
		*supported = if is_supported { 1 } else { 0 }
	}

	return sql_success
}

// feature_info_arg is a trimmed string argument. It can't be a zero-length string
// before it's trimmed: CLI-specific condition — invalid string length or buffer
// length. An argument of only spaces is trimmed to a zero-length string, which
// isn't a feature (General Rules, 7 or 12).
fn feature_info_arg(s &char, length i16) !string {
	if s == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}
	if length < 0 && length != sql_nts {
		return cli_error('HY090', 'invalid string length or buffer length')
	}
	v := input_string(s, i64(length))!
	if v == '' {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	return v.trim(' ')
}
