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

	// - 1. The StatementHandle is used if it identifies an allocated
	// SQL-statement, otherwise the ConnectionHandle is used if the
	// StatementHandle is zero, otherwise the EnvironmentHandle is used if the
	// ConnectionHandle is zero.
	ht, ih := if sh in stmts {
		sql_handle_stmt, sh
	} else if sh == 0 && ch in dbcs {
		sql_handle_dbc, ch
	} else if ch == 0 && eh in envs {
		sql_handle_env, eh
	} else {
		// - 1.d. Otherwise, an exception condition is raised: CLI-specific
		// condition — invalid handle.
		return sql_invalid_handle
	}
	mut diag := handle_diagnostics(ht, ih) or { return sql_invalid_handle }

	// - 3. If every status record has already been processed by Error, then a
	// completion condition is raised: no data, and Sqlstate is set to '00000'.
	if diag.processed >= diag.records.len {
		if sqlstate != unsafe { nil } {
			copy_c_string(sqlstate, '00000', 6, null_termination(handle_env(ht, ih)))
		}
		return sql_no_data
	}

	// - 4. Information is retrieved by implicitly executing GetDiagRec for the
	// first status record not yet processed by Error.
	rc := sql_get_diag_rec(ht, SQLInteger(ih), i16(diag.processed + 1), sqlstate, native_error,
		message_text, buffer_length, text_length)

	// - 5. Add SR to the list of status records already processed by Error.
	if rc != sql_error {
		diag.processed++
	}

	return rc
}
