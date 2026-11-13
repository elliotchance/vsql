module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.38, GetInfo
//
// Get information about the implementation.
//
// The sizes and the implementation information are the rows of the SQL_SIZING
// and SQL_IMPLEMENTATION_INFO views of the INFORMATION_SCHEMA (General Rules,
// 10.a, 10.b and 10.c). They're read from vsql.sql_sizing() and
// vsql.sql_implementation_info(), which the views are built from, rather than
// by an implicit ExecDirect (General Rules, 4 and 9), so that GetInfo can't
// start an SQL-transaction or fail. A maximum of 0 (zero) means that there
// isn't a limit. There are no implementation-defined information types
// (General Rules, 10.p and 10.q).
// Cursors are a copy of the result, so CURSOR SENSITIVITY is INSENSITIVE
// (General Rules, 10.e). There are no users, so USER NAME is a zero-length
// string (General Rules, 10.n).

// Codes from Table 28, "Codes and data types for implementation information"
// (and the deprecated ones from Annex A, "Typical header files").
const sql_maximum_driver_connections = 0
const sql_maximum_concurrent_activities = 1
const sql_data_source_name = 2
const sql_fetch_direction = 8
const sql_server_name = 13
const sql_search_pattern_escape = 14
const sql_dbms_name = 17
const sql_dbms_version = 18
const sql_cursor_commit_behavior = 23
const sql_data_source_read_only = 25
const sql_default_transaction_isolation = 26
const sql_identifier_case = 28
const sql_maximum_column_name_length = 30
const sql_maximum_cursor_name_length = 31
const sql_maximum_schema_name_length = 32
const sql_maximum_catalog_name_length = 34
const sql_maximum_table_name_length = 35
const sql_scroll_concurrency = 43
const sql_transaction_capable = 46
const sql_user_name = 47
const sql_transaction_isolation_option = 72
const sql_integrity = 73
const sql_getdata_extensions = 81
const sql_null_collation = 85
const sql_alter_table = 86
const sql_order_by_columns_in_select = 90
const sql_special_characters = 94
const sql_maximum_columns_in_group_by = 97
const sql_maximum_columns_in_order_by = 99
const sql_maximum_columns_in_select = 100
const sql_maximum_columns_in_table = 101
const sql_maximum_tables_in_select = 106
const sql_maximum_user_name_length = 107
const sql_outer_join_capabilities = 115
const sql_cursor_sensitivity = 10001
const sql_describe_parameter = 10002
const sql_catalog_name = 10003
const sql_collating_sequence = 10004
const sql_maximum_identifier_length = 10005
const sql_maximum_stmt_octets = 20000
const sql_maximum_stmt_octets_data = 20001
const sql_maximum_stmt_octets_schema = 20002

// Values from Table 30 to Table 34, and Annex A, "Typical header files".
const sql_at_add_column = 0x00000001
const sql_at_drop_column = 0x00000002
const sql_at_alter_column = 0x00000004
const sql_at_add_constraint = 0x00000008
const sql_at_drop_constraint = 0x00000010
const sql_cb_delete = 0
const sql_cb_close = 1
const sql_cb_preserve = 2
const sql_fd_fetch_next = 0x00000001
const sql_fd_fetch_first = 0x00000002
const sql_fd_fetch_last = 0x00000004
const sql_fd_fetch_prior = 0x00000008
const sql_fd_fetch_absolute = 0x00000010
const sql_fd_fetch_relative = 0x00000020
const sql_gd_any_column = 0x00000001
const sql_gd_any_order = 0x00000002
const sql_ic_upper = 1
const sql_ic_lower = 2
const sql_ic_sensitive = 3
const sql_ic_mixed = 4
const sql_nc_high = 1
const sql_nc_low = 2
const sql_outer_join_left = 0x00000001
const sql_outer_join_right = 0x00000002
const sql_outer_join_full = 0x00000004
const sql_outer_join_nested = 0x00000008
const sql_outer_join_not_ordered = 0x00000010
const sql_outer_join_inner = 0x00000020
const sql_outer_join_all_comparison_ops = 0x00000040
const sql_scco_read_only = 0x00000001
const sql_scco_lock = 0x00000002
const sql_scco_opt_rowver = 0x00000004
const sql_scco_opt_values = 0x00000008
const sql_tc_none = 0
const sql_tc_dml = 1
const sql_tc_all = 2
const sql_tc_ddl_commit = 3
const sql_tc_ddl_ignore = 4

// InfoValue is the value of an information type: a SMALLINT, an INTEGER or a
// string.
type InfoValue = i16 | int | string

@[export: 'SQLGetInfo']
fn sql_get_info(connection_handle SQLInteger, info_type i16, info_value voidptr, buffer_length i16, string_length &i16) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	return get_info(mut dbc, info_type, info_value, buffer_length, string_length) or {
		dbc.diag.error(err)
	}
}

fn get_info(mut dbc Dbc, info_type i16, info_value voidptr, buffer_length i16, string_length &i16) !i16 {
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

	// - 6, 10. The value of IT, or an exception condition is raised:
	// CLI-specific condition — invalid information type.
	v := info_value_of(dbc, info_type) or {
		return cli_error('HY096', 'invalid information type')
	}

	if info_value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 12. A string is retrieved by the General Rules of Subclause 5.9,
	// "Character string retrieval".
	match v {
		string {
			retrieve_string(mut dbc.diag, null_termination(dbc.env), info_value, v, buffer_length,
				string_length, 2)!
		}
		i16 {
			unsafe {
				*&i16(info_value) = v
			}
		}
		int {
			unsafe {
				*&SQLInteger(info_value) = SQLInteger(v)
			}
		}
	}

	return dbc.diag.result()
}

// info_value_of is the value of an information type, or none if it's not one
// of the codes.
fn info_value_of(dbc &Dbc, info_type i16) ?InfoValue {
	code := int(info_type)

	// - 10.a. The SUPPORTED_VALUE of the SQL_SIZING row, which are all
	// SMALLINT. Only the codes of Table 28 are information types.
	if code < 25000 {
		for item in vsql.sql_sizing() {
			if item.id == code {
				return InfoValue(i16(item.supported_value or { 0 }))
			}
		}
	}

	// - 10.b, 10.c. The CHARACTER_VALUE or INTEGER_VALUE of the
	// SQL_IMPLEMENTATION_INFO row, whichever isn't NULL: 10.b reads CURSOR
	// COMMIT BEHAVIOR and NULL COLLATION from CHARACTER_VALUE, but 7.1,
	// "SQL_IMPLEMENTATION_INFO base table", has them in INTEGER_VALUE (and
	// they're a SMALLINT in Table 28). The DATA SOURCE NAME and SERVER NAME are
	// the ServerName of Connect (which is 'DEFAULT' for the default
	// connection). An INTEGER_VALUE uses the codes of 7.1, which are different
	// for two of them: DEFAULT TRANSACTION ISOLATION is a bit of Table 35 (1 to
	// 4 are 1, 2, 4 and 8), and NULL COLLATION is one more (SQL_NC_HIGH is 1
	// and SQL_NC_LOW is 2, see Annex A). DEFAULT TRANSACTION ISOLATION is the
	// level that SET SESSION CHARACTERISTICS chose, rather than the view's, see
	// default_isolation_level.
	for item in vsql.sql_implementation_info(dbc.server_name) {
		if item.id == code {
			if s := item.character_value {
				return InfoValue(s)
			}
			v := item.integer_value or { 0 }
			return match code {
				sql_default_transaction_isolation { InfoValue(default_isolation_level(dbc)) }
				sql_null_collation { InfoValue(i16(v + 1)) }
				else { InfoValue(i16(v)) }
			}
		}
	}

	return match code {
		// - 10.d to 10.o. The deprecated information types.
		sql_alter_table {
			InfoValue(sql_at_add_column | sql_at_drop_column | sql_at_alter_column | sql_at_add_constraint | sql_at_drop_constraint)
		}
		sql_cursor_sensitivity {
			InfoValue(sql_insensitive)
		}
		sql_data_source_read_only, sql_describe_parameter, sql_order_by_columns_in_select {
			InfoValue('N')
		}
		sql_fetch_direction {
			InfoValue(sql_fd_fetch_next | sql_fd_fetch_first | sql_fd_fetch_last | sql_fd_fetch_prior | sql_fd_fetch_absolute | sql_fd_fetch_relative)
		}
		sql_getdata_extensions {
			InfoValue(sql_gd_any_column | sql_gd_any_order)
		}
		sql_outer_join_capabilities {
			InfoValue(sql_outer_join_left | sql_outer_join_right | sql_outer_join_nested | sql_outer_join_not_ordered | sql_outer_join_inner | sql_outer_join_all_comparison_ops)
		}
		sql_scroll_concurrency {
			InfoValue(sql_scco_read_only)
		}
		sql_transaction_isolation_option {
			InfoValue(sql_transaction_read_uncommitted | sql_transaction_read_committed | sql_transaction_repeatable_read | sql_transaction_serializable)
		}
		sql_user_name {
			InfoValue('')
		}
		sql_integrity {
			InfoValue('Y')
		}
		else {
			none
		}
	}
}

// default_isolation_level is the isolation level of a transaction that doesn't
// set its own, which SET SESSION CHARACTERISTICS can change.
fn default_isolation_level(dbc Dbc) int {
	conn := dbc.conn or { return sql_transaction_serializable }
	return match conn.enduring_isolation_level() {
		'READ UNCOMMITTED' { sql_transaction_read_uncommitted }
		'READ COMMITTED' { sql_transaction_read_committed }
		'REPEATABLE READ' { sql_transaction_repeatable_read }
		else { sql_transaction_serializable }
	}
}
