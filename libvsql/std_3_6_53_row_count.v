module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.53, RowCount
//
// Get the row count.
//
// The row count is the number of rows inserted, updated or deleted by the
// executed statement. It's 0 (zero) for any other statement, since ISO/IEC
// 9075-2 says that it's implementation-dependent.

@[export: 'SQLRowCount']
fn sql_row_count(statement_handle SQLInteger, row_count &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(false) or { return stmt.diag.error(err) }

	// ISO/IEC 9075-3:2003(E), 6.53, RowCount, General Rules, 1 and 2: the
	// statement must have been executed.
	if !stmt.executed {
		return stmt.diag.error(cli_error('HY010', 'function sequence error'))
	}

	// ISO/IEC 9075-3:2003(E), 4.4.3, Null pointers: RowCount can't be a null
	// pointer.
	if row_count == unsafe { nil } {
		return stmt.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// ISO/IEC 9075-3:2003(E), 6.53, RowCount, General Rules, 3
	unsafe {
		*row_count = SQLInteger(stmt.row_count)
	}

	return sql_success
}

// row_count_of is the number of rows affected by an INSERT, UPDATE or DELETE,
// which is the number at the end of its message (such as "INSERT 3").
fn row_count_of(result vsql.Result) int {
	for prefix in ['INSERT ', 'UPDATE ', 'DELETE '] {
		if result.msg.starts_with(prefix) {
			return result.msg.all_after(prefix).int()
		}
	}

	return 0
}
