module main

// ISO/IEC 9075-3:2003(E), 6.18, Error
//
// Return diagnostic information.
//
// Each call returns the next status record of the diagnostics area that hasn't
// already been returned by Error.

@[export: 'SQLError']
fn sql_error_routine(environment_handle SQLInteger, connection_handle SQLInteger, statement_handle SQLInteger, sqlstate &char, native_error &SQLInteger, message_text &char, buffer_length i16, text_length &i16) i16 {
	entry := enter(error_handle_type(connection_handle, statement_handle), error_handle(environment_handle, connection_handle, statement_handle))
	defer {
		entry.leave()
	}
	sh := i64(statement_handle)
	ch := i64(connection_handle)
	eh := i64(environment_handle)

	// ISO/IEC 9075-3:2003(E), 6.18, Error, General Rules, 1.a-c: the
	// StatementHandle is used if it identifies an allocated SQL-statement,
	// otherwise the ConnectionHandle is used if the StatementHandle is zero,
	// otherwise the EnvironmentHandle is used if the ConnectionHandle is zero.
	ht, ih := if sh in stmts {
		sql_handle_stmt, sh
	} else if sh == 0 && ch in dbcs {
		sql_handle_dbc, ch
	} else if ch == 0 && eh in envs {
		sql_handle_env, eh
	} else {
		// ISO/IEC 9075-3:2003(E), 6.18, Error, General Rules, 1.d
		return sql_invalid_handle
	}
	mut diag := handle_diagnostics(ht, ih) or { return sql_invalid_handle }

	// ISO/IEC 9075-3:2003(E), 6.18, Error, General Rules, 2 and 3: the status
	// records are of the last routine (other than Error, GetDiagField and
	// GetDiagRec) for the handle. When they've all been returned, it's no data
	// with an Sqlstate of 00000.
	if diag.processed >= diag.records.len {
		if sqlstate != unsafe { nil } {
			copy_c_string(sqlstate, '00000', 6, null_termination(handle_env(ht, ih)))
		}
		return sql_no_data
	}

	// ISO/IEC 9075-3:2003(E), 6.18, Error, General Rules, 4: the first status
	// record that hasn't been returned is returned by GetDiagRec.
	rc := sql_get_diag_rec(ht, SQLInteger(ih), i16(diag.processed + 1), sqlstate, native_error,
		message_text, buffer_length, text_length)

	// ISO/IEC 9075-3:2003(E), 6.18, Error, General Rules, 5
	if rc != sql_error {
		diag.processed++
	}

	return rc
}
