module main

// ISO/IEC 9075-3:2003(E), 6.34, GetDiagRec
//
// Get commonly-used information from a CLI diagnostics area.
//
// GetDiagRec doesn't generate diagnostic information, so its own exception
// conditions only return SQL_ERROR. The NativeError is always 0.

@[export: 'SQLGetDiagRec']
fn sql_get_diag_rec(handle_type i16, handle SQLInteger, record_number i16, sqlstate &char, native_error &SQLInteger, message_text &char, buffer_length i16, text_length &i16) i16 {
	// - 2, 3. The handle must identify an allocated resource of HT.
	diag := handle_diagnostics(handle_type, i64(handle)) or { return sql_invalid_handle }

	// - 6. If RN is less than 1 (one), then an exception condition is raised:
	// invalid condition number.
	if record_number < 1 {
		return sql_error
	}

	// - 7. If RN is greater than N, then a completion condition is raised: no
	// data.
	if record_number > diag.records.len {
		return sql_no_data
	}

	record := diag.records[record_number - 1]

	if sqlstate != unsafe { nil } {
		copy_c_string(sqlstate, record.sqlstate, 6)
	}

	if native_error != unsafe { nil } {
		unsafe {
			*native_error = 0
		}
	}

	// - 9.c.ii. If BL is not greater than zero, then an exception condition is
	// raised: CLI-specific condition — invalid string length or buffer length.
	// The message is truncated without a warning.
	if message_text != unsafe { nil } {
		if buffer_length <= 0 {
			return sql_error
		}
		set_length(text_length, 2, record.msg.len)
		copy_c_string(message_text, record.msg, buffer_length)
	}

	return sql_success
}
