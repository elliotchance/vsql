module main

// ISO/IEC 9075-3:2003(E), 6.48, NumResultCols
//
// Get the number of result columns.

@[export: 'SQLNumResultCols']
fn sql_num_result_cols(statement_handle SQLInteger, column_count &i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(false) or { return stmt.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.48, NumResultCols, General Rules, 1 and 2.a: the
	// statement must have been prepared or executed.
	if !stmt.executed && stmt.prepared == none {
		return stmt.diag.error(cli_error('HY010', 'function sequence error'))
	}

	// ISO/IEC 9075-3:2003(E), 4.4.3, Null pointers: ColumnCount can't be a
	// null pointer.
	if column_count == unsafe { nil } {
		return stmt.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// ISO/IEC 9075-3:2003(E), 6.48, NumResultCols, General Rules, 2.b and 3:
	// ColumnCount is the TOP_LEVEL_COUNT of the IRD, which is zero for a
	// statement that isn't a cursor specification.
	ird := descs[stmt.ird] or { return sql_invalid_handle }
	unsafe {
		*column_count = i16(ird.header_int(sql_desc_top_level_count))
	}

	return sql_success
}
