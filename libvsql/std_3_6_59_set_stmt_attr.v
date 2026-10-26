module main

// ISO/IEC 9075-3:2003(E), 6.59, SetStmtAttr
//
// Set the value of an SQL-statement attribute.
//
// The attribute is passed as the Value itself (rather than a pointer to it),
// the same as ODBC.
//
// A cursor is a copy of the result, so it can be scrollable and holdable, and
// it's ASENSITIVE or INSENSITIVE (a SENSITIVE cursor can't be opened).

@[export: 'SQLSetStmtAttr']
fn sql_set_stmt_attr(statement_handle SQLInteger, attribute SQLInteger, value voidptr, string_length SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return set_stmt_attr(mut stmt, attribute, i64(value)) or { stmt.diag.error(err) }
}

fn set_stmt_attr(mut stmt Stmt, attribute SQLInteger, v i64) !i16 {
	match i64(attribute) {
		// - 5.a, 5.b. The APD or ARD becomes a descriptor allocated by the
		// application (for any connection), or the automatically allocated
		// one for this statement.
		sql_attr_app_param_desc, sql_attr_app_row_desc {
			is_ard := attribute == sql_attr_app_row_desc
			desc := descs[v] or { return cli_error('HY024', 'invalid attribute value') }
			if desc.stmt != 0 && v != (if is_ard { stmt.auto_ard } else { stmt.auto_apd }) {
				return cli_error('HY017', 'invalid use of automatically-allocated descriptor handle')
			}
			if is_ard {
				stmt.ard = v
			} else {
				stmt.apd = v
			}
		}
		sql_attr_cursor_scrollable {
			check_no_cursor(stmt)!
			stmt.cursor_scrollable = check_attr_value(v, [i64(sql_nonscrollable), sql_scrollable])!
		}
		sql_attr_cursor_sensitivity {
			check_no_cursor(stmt)!
			stmt.cursor_sensitivity = check_attr_value(v, [i64(sql_asensitive), sql_insensitive,
				sql_sensitive])!
		}
		sql_attr_metadata_id {
			stmt.metadata_id = check_attr_value(v, [i64(sql_false), sql_true])!
		}
		sql_attr_cursor_holdable {
			check_no_cursor(stmt)!
			stmt.cursor_holdable = check_attr_value(v, [i64(sql_nonholdable), sql_holdable])!
		}
		sql_attr_current_of_position {
			// - 5.g. The cursor must be open and scrollable, and V can't be more
			// than the ARRAY_SIZE of the ARD.
			if stmt.cursor == none {
				return cli_error('24000', 'invalid cursor state')
			}
			ard := descs[stmt.ard] or { return cli_error('HY010', 'function sequence error') }
			if v > ard.header_int(sql_desc_array_size) {
				return cli_error('HY107', 'row value out of range')
			}
			if stmt.cursor_scrollable == sql_nonscrollable {
				return cli_error('HY109', 'invalid cursor position')
			}
			stmt.current_of_position = v
			stmt.fetched_column = 0
		}
		sql_attr_nest_descriptor {
			// - 5.h.i. If there is a prepared statement associated with
			// StatementHandle, then an exception condition is raised:
			// CLI-specific condition — function sequence error.
			if stmt.executed {
				return cli_error('HY010', 'function sequence error')
			}
			stmt.nest_descriptor = check_attr_value(v, [i64(sql_false), sql_true])!
		}
		else {
			// - 3. If A is not one of the code values in Table 17, or it can't be
			// set (IPD HANDLE and IRD HANDLE), then an exception condition is
			// raised: CLI-specific condition — invalid attribute identifier.
			return cli_error('HY092', 'invalid attribute identifier')
		}
	}

	return sql_success
}

// check_no_cursor raises an exception condition if there's an open cursor:
// CLI-specific condition — attribute cannot be set now.
fn check_no_cursor(stmt &Stmt) ! {
	if stmt.cursor != none {
		return cli_error('HY011', 'attribute cannot be set now')
	}
}

// check_attr_value returns v if it's one of the allowed values, otherwise an
// exception condition is raised: CLI-specific condition — invalid attribute
// value.
fn check_attr_value(v i64, allowed []i64) !i64 {
	if v !in allowed {
		return cli_error('HY024', 'invalid attribute value')
	}

	return v
}
