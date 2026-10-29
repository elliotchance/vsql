module main

// ISO/IEC 9075-3:2003(E), 6.21, Fetch
//
// Fetch the next row of a cursor.
//
// The next rowset (of ARRAY_SIZE rows from the ARD) is assigned to the bound
// targets, see 5.8, "Implicit FETCH USING clause".

@[export: 'SQLFetch']
fn sql_fetch(statement_handle SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return fetch(mut stmt, sql_fetch_next, 0) or { stmt.diag.error(err) }
}

// fetch positions the cursor on a rowset (for FetchScroll, or NEXT for Fetch)
// and assigns its rows to the bound targets.
fn fetch(mut stmt Stmt, orientation i16, offset i64) !i16 {
	// - 2. If there is no executed statement associated with S, then an
	// exception condition is raised: CLI-specific condition — function sequence
	// error.
	if !stmt.executed {
		return cli_error('HY010', 'function sequence error')
	}

	// - 3. If there is no open cursor associated with S, then an exception
	// condition is raised: invalid cursor state.
	if stmt.cursor == none {
		return cli_error('24000', 'invalid cursor state')
	}

	// The bound targets are checked before the cursor moves.
	targets := bound_targets(stmt)!

	ard := descs[stmt.ard] or { return cli_error('HY010', 'function sequence error') }
	start, len, is_no_data := scroll(stmt.rows.len, int(ard.header_int(sql_desc_array_size)),
		stmt.rowset_start, stmt.rowset_len, orientation, offset)
	stmt.fetched = true
	stmt.fetched_column = 0
	if is_no_data {
		// The position is unchanged by a RELATIVE 0 that has no rowset.
		if !(orientation == sql_fetch_relative && offset == 0) {
			stmt.rowset_start = start
			stmt.rowset_len = 0
		}
		stmt.position_cursor()
		return no_data()
	}
	stmt.rowset_start = start
	stmt.rowset_len = len

	// The CURRENT OF POSITION is reset to the first row of the rowset (see
	// 4.4.6, "Statement attributes").
	stmt.current_of_position = 1
	stmt.position_cursor()

	return fetch_using(mut stmt, targets)
}
