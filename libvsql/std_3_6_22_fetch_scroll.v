module main

// ISO/IEC 9075-3:2003(E), 6.22, FetchScroll
//
// Position a cursor on the specified row and retrieve values from that row.
//
// The cursor is a copy of the result, so it can be scrollable. NEXT is the same
// as Fetch, and moves to the rowset after the current one. PRIOR moves to the
// rowset of ARRAY_SIZE rows before the current one (or the first rowset).
// RELATIVE moves from the first row of the current rowset, and ABSOLUTE counts
// from the start (or the end, if it's negative).

// Codes from Table 24, "Codes used for fetch orientation".
const sql_fetch_next = i16(1)
const sql_fetch_first = i16(2)
const sql_fetch_last = i16(3)
const sql_fetch_prior = i16(4)
const sql_fetch_absolute = i16(5)
const sql_fetch_relative = i16(6)

@[export: 'SQLFetchScroll']
fn sql_fetch_scroll(statement_handle SQLInteger, fetch_orientation i16, fetch_offset SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return fetch_scroll(mut stmt, fetch_orientation, i64(fetch_offset)) or {
		stmt.diag.error(err)
	}
}

fn fetch_scroll(mut stmt Stmt, orientation i16, offset i64) !i16 {
	if !stmt.executed {
		return cli_error('HY010', 'function sequence error')
	}
	if stmt.cursor == none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 4. If FetchOrientation is not one of the code values in Table 24, then
	// an exception condition is raised: CLI-specific condition — invalid fetch
	// orientation.
	if orientation < sql_fetch_next || orientation > sql_fetch_relative {
		return cli_error('HY106', 'invalid fetch orientation')
	}

	// - 6. If the value of the CURSOR SCROLLABLE attribute of S is
	// NONSCROLLABLE, and FO does not indicate NEXT, then an exception condition
	// is raised: CLI-specific condition — invalid fetch orientation.
	if stmt.cursor_scrollable == sql_nonscrollable && orientation != sql_fetch_next {
		return cli_error('HY106', 'invalid fetch orientation')
	}

	return fetch(mut stmt, orientation, offset)
}

// scroll returns the rowset (start and length) that a cursor with n rows moves
// to from the rowset at start (with len rows), or true if there's no rowset
// (and start is before the first row, -1, or after the last row, n). See
// General Rules 11 to 15.
fn scroll(n int, array_size int, start int, len int, orientation i16, offset i64) (int, int, bool) {
	rowset := fn [n, array_size] (s int) (int, int, bool) {
		return s, if s + array_size > n { n - s } else { array_size }, false
	}
	before := -1
	after := n

	match orientation {
		sql_fetch_first {
			if n == 0 {
				return before, 0, true
			}
			return rowset(0)
		}
		sql_fetch_last {
			if n == 0 {
				return after, 0, true
			}
			return rowset(if n > array_size { n - array_size } else { 0 })
		}
		sql_fetch_prior {
			// - 13.c. There's nothing before the first row.
			if n == 0 || start <= 0 {
				return before, 0, true
			}
			if start == after {
				return rowset(if n > array_size { n - array_size } else { 0 })
			}
			return rowset(if start > array_size { start - array_size } else { 0 })
		}
		sql_fetch_absolute {
			// - 14. A negative J counts back from the last row, and zero is the
			// first row.
			k := if offset > 0 {
				offset
			} else if offset < 0 {
				n + offset + 1
			} else {
				1
			}
			return scroll_to(n, array_size, k)
		}
		sql_fetch_relative {
			if offset == 0 {
				return start, len, len == 0
			}
			if offset > 0 {
				// - 13.b. The rows after the first row of the rowset.
				if n == 0 || start + len >= n {
					return after, 0, true
				}
				k := if start == before { offset } else { start + 1 + offset }
				return scroll_to(n, array_size, k)
			}

			// - 13.c. The rows before the first row of the rowset.
			rows_before := if start == after {
				n
			} else if start < 0 {
				0
			} else {
				start
			}
			return scroll_to(n, array_size, rows_before + offset + 1)
		}
		else {
			// - 10. NEXT: the rows after the last row of the rowset.
			if n == 0 || start + len >= n {
				return after, 0, true
			}
			return rowset(if start == before { 0 } else { start + len })
		}
	}
}

// scroll_to returns the rowset that starts at the K-th row (from 1) of n rows.
// A K that's before the first row, but not by more than the ARRAY_SIZE, is the
// first rowset (- 15.b).
fn scroll_to(n int, array_size int, k i64) (int, int, bool) {
	if k > n {
		return n, 0, true
	}
	if k >= 1 {
		s := int(k - 1)
		return s, if s + array_size > n { n - s } else { array_size }, false
	}
	if k < 0 && -k <= array_size && n > 0 {
		return 0, if array_size > n { n } else { array_size }, false
	}

	return -1, 0, true
}
