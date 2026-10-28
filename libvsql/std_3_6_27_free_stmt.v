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
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.
	stmt.invoke(false) or { return stmt.diag.error(err) }

	match option {
		// - 6.a. If OPT indicates CLOSE CURSOR and there is an open cursor
		// associated with S, then the cursor is closed. Unlike CloseCursor, it's
		// not an error if there isn't an open cursor.
		sql_close_cursor {
			stmt.close_cursor()
		}
		// - 6.b. If OPT indicates FREE HANDLE, then FreeHandle is implicitly
		// invoked with HandleType indicating STATEMENT HANDLE.
		sql_free_handle {
			return sql_free_handle(sql_handle_stmt, statement_handle)
		}
		// - 6.c, 6.d. The DATA_POINTER of each ARD (or APD) item descriptor area
		// is set to zero.
		sql_unbind_columns, sql_unbind_parameters {
			mut desc := descs[if option == sql_unbind_columns { stmt.ard } else { stmt.apd }] or {
				return sql_invalid_handle
			}
			for i in 0 .. desc.count() {
				desc.records[i][sql_desc_data_pointer] = i64(0)
			}
		}
		// - 6.e. If OPT indicates REALLOCATE, then any prepared statement,
		// cursor, select source and executed statement associated with S are
		// destroyed, and the automatically allocated descriptors go back to
		// their default values.
		sql_reallocate {
			stmt.prepared = none
			stmt.close_cursor()
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
			// - 3. If OPT is not one of the codes in Table 18, then an exception
			// condition is raised: CLI-specific condition — invalid attribute
			// identifier.
			return stmt.diag.error(cli_error('HY092', 'invalid attribute identifier'))
		}
	}

	return sql_success
}
