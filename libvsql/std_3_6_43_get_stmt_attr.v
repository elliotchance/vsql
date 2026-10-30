module main

// ISO/IEC 9075-3:2003(E), 6.43, GetStmtAttr
//
// Get the value of an SQL-statement attribute.

// Codes from Table 17, "Codes used for statement attributes".
const sql_attr_cursor_holdable = -3
const sql_attr_cursor_sensitivity = -2
const sql_attr_cursor_scrollable = -1
const sql_attr_app_row_desc = 10010
const sql_attr_app_param_desc = 10011
const sql_attr_imp_row_desc = 10012
const sql_attr_imp_param_desc = 10013
const sql_attr_metadata_id = 10014
const sql_attr_current_of_position = 10027
const sql_attr_nest_descriptor = 10029

// Codes from Table 26, "Miscellaneous codes used in CLI".
const sql_nonscrollable = 0
const sql_scrollable = 1
const sql_asensitive = 0
const sql_insensitive = 1
const sql_sensitive = 2
const sql_nonholdable = 0
const sql_holdable = 1

@[export: 'SQLGetStmtAttr']
fn sql_get_stmt_attr(statement_handle SQLInteger, attribute SQLInteger, value voidptr, buffer_length SQLInteger, string_length &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return get_stmt_attr(stmt, attribute, value) or { stmt.diag.error(err) }
}

fn get_stmt_attr(stmt &Stmt, attribute SQLInteger, value voidptr) !i16 {
	// - 3. If A is not one of the code values in Table 17, then an exception
	// condition is raised: CLI-specific condition — invalid attribute
	// identifier.
	v := match i64(attribute) {
		sql_attr_app_param_desc {
			stmt.apd
		}
		sql_attr_app_row_desc {
			stmt.ard
		}
		sql_attr_imp_param_desc {
			stmt.ipd
		}
		sql_attr_imp_row_desc {
			stmt.ird
		}
		sql_attr_cursor_scrollable {
			stmt.cursor_scrollable
		}
		sql_attr_cursor_sensitivity {
			stmt.cursor_sensitivity
		}
		sql_attr_metadata_id {
			stmt.metadata_id
		}
		sql_attr_cursor_holdable {
			stmt.cursor_holdable
		}
		sql_attr_current_of_position {
			// - 4.i.i. If there is no fetched rowset associated with S, then an
			// exception condition is raised: CLI-specific condition — invalid
			// cursor state.
			if !stmt.fetched {
				return cli_error('24000', 'invalid cursor state')
			}
			stmt.current_of_position
		}
		sql_attr_nest_descriptor {
			stmt.nest_descriptor
		}
		else {
			return cli_error('HY092', 'invalid attribute identifier')
		}
	}

	if value == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	unsafe {
		*&SQLInteger(value) = SQLInteger(v)
	}

	return sql_success
}
