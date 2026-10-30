module main

// ISO/IEC 9075-3:2003(E), 6.27, FreeStmt
//
// Deallocate an SQL-statement.

// Codes from Table 18, "Codes used for FreeStmt options". The second names are
// the ones used by ODBC.
const sql_close_cursor = i16(0)
const sql_free_handle = i16(1)
const sql_unbind_columns = i16(2)
const sql_unbind_parameters = i16(3)
const sql_reallocate = i16(4)
const sql_close = i16(0)
const sql_drop = i16(1)
const sql_unbind = i16(2)
const sql_reset_params = i16(3)

@[export: 'SQLFreeStmt']
fn sql_free_stmt(statement_handle SQLInteger, option i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(false) or { return stmt.diag.error(err) }

	match option {
		// ISO/IEC 9075-3:2003(E), 6.27, FreeStmt, General Rules, 6.a: an open
		// cursor is closed. Unlike CloseCursor, it's not an error if there
		// isn't an open cursor.
		sql_close_cursor {
			stmt.close_cursor()
			autocommit(mut stmt.diag, stmt.dbc, true) or { return stmt.diag.error(err) }
		}
		// ISO/IEC 9075-3:2003(E), 6.27, FreeStmt, General Rules, 6.b
		sql_free_handle {
			return sql_free_handle(sql_handle_stmt, statement_handle)
		}
		// ISO/IEC 9075-3:2003(E), 6.27, FreeStmt, General Rules, 4, 5, 6.c and
		// 6.d: the DATA_POINTER of each ARD (or APD) item descriptor area is set
		// to zero.
		sql_unbind_columns, sql_unbind_parameters {
			mut desc := descs[if option == sql_unbind_columns { stmt.ard } else { stmt.apd }] or {
				return sql_invalid_handle
			}
			for i in 0 .. desc.count() {
				desc.records[i][sql_desc_data_pointer] = i64(0)
			}
		}
		// ISO/IEC 9075-3:2003(E), 6.27, FreeStmt, General Rules, 6.e: the
		// prepared statement, cursor, select source and executed statement are
		// destroyed, and the automatically allocated descriptors go back to
		// their default values.
		sql_reallocate {
			stmt.prepared = none
			stmt.close_cursor()
			autocommit(mut stmt.diag, stmt.dbc, true) or { return stmt.diag.error(err) }
			stmt.executed = false
			stmt.row_count = 0
			stmt.ard = stmt.auto_ard
			stmt.apd = stmt.auto_apd
			for dh in [stmt.auto_ard, stmt.auto_apd, stmt.ird, stmt.ipd] {
				mut desc := descs[dh] or { continue }
				desc.reset()
			}
		}
		else {
			// ISO/IEC 9075-3:2003(E), 6.27, FreeStmt, General Rules, 2 and 3: the
			// option must be one of the codes in Table 18.
			return stmt.diag.error(cli_error('HY092', 'invalid attribute identifier'))
		}
	}

	return sql_success
}
