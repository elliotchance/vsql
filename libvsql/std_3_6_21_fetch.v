module main

// ISO/IEC 9075-3:2003(E), 6.21, Fetch
//
// Fetch the next row of a cursor.

@[export: 'SQLFetch']
fn sql_fetch(statement_handle SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return fetch(mut stmt) or { stmt.diag.error(err) }
}

fn fetch(mut stmt Stmt) !i16 {
	// - 2. If there is no executed statement associated with S, then an
	// exception condition is raised: CLI-specific condition — function sequence
	// error.
	if !stmt.executed {
		return cli_error('HY010', 'function sequence error')
	}

	// - 3. If there is no open cursor associated with S, then an exception
	// condition is raised: invalid cursor state.
	mut cursor := stmt.cursor or { return cli_error('24000', 'invalid cursor state') }

	stmt.row = cursor.next()
	stmt.cursor = cursor
	stmt.fetched = true
	stmt.fetched_column = 0

	// The CURRENT OF POSITION is reset to the first row of the rowset (see
	// 4.4.6, "Statement attributes").
	stmt.current_of_position = 1

	// - 9. If T is empty, or if R contains the last row of T, then CR is
	// positioned after the last row and a completion condition is raised: no
	// data.
	if stmt.row == none {
		return stmt.diag.no_data()
	}

	return sql_success
}
