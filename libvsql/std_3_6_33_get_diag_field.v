module main

// ISO/IEC 9075-3:2003(E), 6.33, GetDiagField
//
// Get information from a CLI diagnostics area.
//
// GetDiagField doesn't generate diagnostic information, so its own exception
// conditions only return SQL_ERROR. vsql conditions don't identify a
// constraint, table, column, cursor, routine or trigger, so those fields are
// always zero-length strings.

// Codes from Table 12, "Codes used for SQL/CLI diagnostic fields".
const sql_diag_returncode = i16(1)
const sql_diag_number = i16(2)
const sql_diag_row_count = i16(3)
const sql_diag_sqlstate = i16(4)
const sql_diag_native_code = i16(5)
const sql_diag_message_text = i16(6)
const sql_diag_dynamic_function = i16(7)
const sql_diag_class_origin = i16(8)
const sql_diag_subclass_origin = i16(9)
const sql_diag_connection_name = i16(10)
const sql_diag_server_name = i16(11)
const sql_diag_dynamic_function_code = i16(12)
const sql_diag_more = i16(13)
const sql_diag_condition_number = i16(14)
const sql_diag_constraint_catalog = i16(15)
const sql_diag_constraint_schema = i16(16)
const sql_diag_constraint_name = i16(17)
const sql_diag_catalog_name = i16(18)
const sql_diag_schema_name = i16(19)
const sql_diag_table_name = i16(20)
const sql_diag_column_name = i16(21)
const sql_diag_cursor_name = i16(22)
const sql_diag_message_length = i16(23)
const sql_diag_message_octet_length = i16(24)
const sql_diag_condition_identifier = i16(25)
const sql_diag_parameter_name = i16(26)
const sql_diag_routine_catalog = i16(27)
const sql_diag_routine_schema = i16(28)
const sql_diag_routine_name = i16(29)
const sql_diag_specific_name = i16(30)
const sql_diag_trigger_catalog = i16(31)
const sql_diag_trigger_schema = i16(32)
const sql_diag_trigger_name = i16(33)
const sql_diag_transactions_committed = i16(34)
const sql_diag_transactions_rolled_back = i16(35)
const sql_diag_transaction_active = i16(36)
const sql_diag_parameter_mode = i16(37)
const sql_diag_parameter_ordinal_position = i16(38)
const sql_diag_row_number = i16(-1248)
const sql_diag_column_number = i16(-1247)

// The DYNAMIC_FUNCTION_CODEs from Table 31, "SQL-statement codes", in ISO/IEC
// 9075-2 that are in Annex A, "Typical header files".
const sql_diag_unknown_statement = 0
const sql_diag_alter_table = 4
const sql_diag_create_schema = 64
const sql_diag_create_table = 77
const sql_diag_delete_where = 19
const sql_diag_drop_schema = 31
const sql_diag_drop_table = 32
const sql_diag_insert = 50
const sql_diag_select_cursor = 85
const sql_diag_set_catalog = 66
const sql_diag_set_schema = 74
const sql_diag_update_where = 82

// diag_info is the value of a diagnostics field, which is either an integer or
// a character string.
type DiagInfo = int | string

@[export: 'SQLGetDiagField']
fn sql_get_diag_field(handle_type i16, handle SQLInteger, record_number i16, diag_identifier i16, diag_info voidptr, buffer_length i16, string_length &i16) i16 {
	entry := enter(handle_type, i64(handle))
	defer {
		entry.leave()
	}
	h := i64(handle)

	// - 2, 3. The handle must identify an allocated resource of HT.
	diag := handle_diagnostics(handle_type, h) or { return sql_invalid_handle }

	return get_diag_field(handle_type, h, diag, record_number, diag_identifier, diag_info,
		buffer_length, string_length) or { sql_error }
}

fn get_diag_field(handle_type i16, h i64, diag &Diagnostics, record_number i16, diag_identifier i16, diag_info voidptr, buffer_length i16, string_length &i16) !i16 {
	// - 5. If DI is not one of the code values in Table 12, then an exception
	// condition is raised: CLI-specific condition — invalid attribute value.
	is_header := diag_identifier in [sql_diag_dynamic_function, sql_diag_dynamic_function_code,
		sql_diag_more, sql_diag_number, sql_diag_returncode, sql_diag_row_count,
		sql_diag_transactions_committed, sql_diag_transactions_rolled_back,
		sql_diag_transaction_active]
	if !is_header && (diag_identifier < sql_diag_sqlstate
		|| diag_identifier > sql_diag_parameter_ordinal_position)
		&& diag_identifier !in [sql_diag_row_number, sql_diag_column_number] {
		return cli_error('HY024', 'invalid attribute value')
	}

	// - 9. A status record must exist, otherwise a completion condition is
	// raised: no data.
	if !is_header {
		if record_number < 1 {
			return cli_error('35000', 'invalid condition number')
		}
		if record_number > diag.records.len {
			return sql_no_data
		}
	}

	// - 10. If DI indicates ROW_COUNT and R is neither Execute nor ExecDirect,
	// then an exception condition is raised: CLI-specific condition — invalid
	// attribute identifier.
	if diag_identifier == sql_diag_row_count && !diag.is_execute {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	value := if is_header {
		diag_header_field(handle_type, h, diag, diag_identifier)
	} else {
		diag_status_field(handle_type, h, diag.records[record_number - 1], record_number,
			diag_identifier)
	}

	if diag_info == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	match value {
		int {
			// - 14. A field that isn't a character string is set directly.
			// RETURNCODE is the only SMALLINT.
			unsafe {
				if diag_identifier == sql_diag_returncode {
					*&i16(diag_info) = i16(value)
				} else {
					*&SQLInteger(diag_info) = SQLInteger(value)
				}
			}
		}
		string {
			// - 16. If BL is not greater than zero, then an exception condition is
			// raised: CLI-specific condition — invalid string length or buffer
			// length.
			if buffer_length <= 0 {
				return cli_error('HY090', 'invalid string length or buffer length')
			}

			// - 17, 18, 19. The value is truncated (without a warning), and null
			// terminated if null termination is True.
			set_length(string_length, 2, value.len)
			copy_c_string(diag_info, value, buffer_length, null_termination(handle_env(handle_type,
				h)))
		}
	}

	return sql_success
}

// - 11. Header information.
fn diag_header_field(handle_type i16, h i64, diag &Diagnostics, diag_identifier i16) DiagInfo {
	return match diag_identifier {
		sql_diag_number { diag.records.len }
		sql_diag_dynamic_function { diag.dynamic_function }
		sql_diag_dynamic_function_code { diag.dynamic_function_code }
		sql_diag_returncode { int(diag.returncode) }
		sql_diag_row_count { diag.row_count }
		sql_diag_transactions_committed { diag.transactions_committed }
		sql_diag_transactions_rolled_back { diag.transactions_rolled_back }
		sql_diag_transaction_active { int(transaction_active(handle_type, h)) }
		// - 11.f. Every condition is stored in the diagnostics area.
		else { 0 }
	}
}

// - 12. Information from the RN-th status record.
fn diag_status_field(handle_type i16, h i64, record DiagnosticRecord, record_number int, diag_identifier i16) DiagInfo {
	return match diag_identifier {
		sql_diag_condition_number { record_number }
		sql_diag_sqlstate { record.sqlstate }
		sql_diag_native_code { 0 }
		sql_diag_message_text { record.msg }
		sql_diag_message_length { record.msg.runes().len }
		sql_diag_message_octet_length { record.msg.len }
		sql_diag_class_origin { origin(record.sqlstate[..2]) }
		sql_diag_subclass_origin { origin(record.sqlstate[2..]) }
		sql_diag_server_name, sql_diag_connection_name { server_name(handle_type, h) }
		// - 12.i.iv. If the value of SQLSTATE corresponds to invalid cursor
		// state, then the value of CURSOR_NAME is the name of the cursor that
		// is in the invalid state.
		sql_diag_cursor_name { cursor_name_of(handle_type, h, record) }
		sql_diag_column_number { record.column_number }
		sql_diag_row_number { record.row_number }
		sql_diag_parameter_ordinal_position { 0 }
		else { '' }
	}
}

// origin is the naming authority of an SQLSTATE class or subclass. Values that
// start with a digit from 0 to 4, or a letter from A to H, are defined by the
// standard (see Subclause 24.1, "SQLSTATE", in ISO/IEC 9075-2).
fn origin(value string) string {
	return if value[0] in '01234ABCDEFGH'.bytes() { 'ISO 9075' } else { 'vsql' }
}

// - 12.j. The SERVER_NAME (and CONNECTION_NAME, which is the same) of the
// SQL-connection, or a zero-length string for an SQL-environment.
fn server_name(handle_type i16, h i64) string {
	dbc := match handle_type {
		sql_handle_dbc { dbcs[h] or { return '' } }
		sql_handle_stmt { dbcs[(stmts[h] or { return '' }).dbc] or { return '' } }
		sql_handle_desc { dbcs[(descs[h] or { return '' }).dbc] or { return '' } }
		else { return '' }
	}

	return dbc.server_name
}

// transaction_active is true if an SQL-transaction is active for the
// connection of the handle, or any connection of an SQL-environment.
fn transaction_active(handle_type i16, h i64) bool {
	for dh, dbc in dbcs {
		matches := match handle_type {
			sql_handle_env { dbc.env == h }
			sql_handle_dbc { dh == h }
			sql_handle_desc { dh == (descs[h] or { return false }).dbc }
			else { dh == (stmts[h] or { return false }).dbc }
		}
		if matches {
			if mut conn := dbc.conn {
				if conn.in_transaction() {
					return true
				}
			}
		}
	}

	return false
}

// skip_bracketed_comment returns the position after the bracketed comment that
// starts at text[start]. Bracketed comments can be nested, so each "/*" needs
// its own "*/".
fn skip_bracketed_comment(text string, start int) int {
	mut depth := 0
	mut i := start
	for i + 1 < text.len {
		if text[i] == `/` && text[i + 1] == `*` {
			depth++
			i += 2
		} else if text[i] == `*` && text[i + 1] == `/` {
			depth--
			i += 2
			if depth == 0 {
				return i
			}
		} else {
			i++
		}
	}

	return text.len
}

fn cursor_name_of(handle_type i16, h i64, record DiagnosticRecord) string {
	if handle_type != sql_handle_stmt || record.sqlstate != '24000' {
		return ''
	}
	mut stmt := stmts[h] or { return '' }

	return stmt.get_cursor_name()
}
