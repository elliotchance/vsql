module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>
//
// Position a standing cursor on a specified row of the standing cursor's result
// set and retrieve values from that row.

// The row is returned as the result, instead of being assigned to a <fetch
// target list> (V110-01).
struct FetchStatement {
	name        string
	orientation FetchOrientation
}

// FetchDirection is the <fetch orientation>, which is NEXT if there isn't one.
//
// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, Syntax Rules, 2
enum FetchDirection {
	next
	prior
	first
	last
	absolute
	relative
}

// FetchOrientation is a <fetch orientation>. value is the row number of
// ABSOLUTE, or the number of rows to move for RELATIVE.
struct FetchOrientation {
	direction FetchDirection
	value     ?ValueSpecification
}

fn (stmt FetchStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut cursor := conn.open_cursor(stmt.name)!

	// Only a SCROLL cursor can be fetched in a direction other than NEXT.
	//
	// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, Syntax Rules, 7
	// ISO/IEC 9075-2:2016(E), 15.3, Determination of the current row of a cursor, General Rules, 4
	if stmt.orientation.direction != .next && !cursor.scroll {
		return sqlstate_42601('cursor ${stmt.name} is not a SCROLL cursor, so it can only FETCH NEXT')
	}

	j := stmt.orientation.number(mut conn, params)!
	cursor.fetched = true

	// The cursor moves to the row, or before the first row or after the last row
	// with no data. The rows of the cursor's result don't change while it's
	// open (including a row that it deleted), so the row is found by its index.
	//
	// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, General Rules, 3 and 4
	if !cursor.move(stmt.orientation.direction, j) {
		conn.add_warning(sqlstate_02000())

		return new_result(cursor.columns, []Row{}, elapsed_parse, t.elapsed())
	}

	return new_result(cursor.columns, [cursor.rows[cursor.position]], elapsed_parse,
		t.elapsed())
}

// number is the value of ABSOLUTE or RELATIVE, which must be an exact numeric
// with scale 0. It's 1 for NEXT and FIRST, and -1 for PRIOR and LAST.
//
// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, Syntax Rules, 8
// ISO/IEC 9075-2:2016(E), 15.3, Determination of the current row of a cursor, General Rules, 5
fn (o FetchOrientation) number(mut conn Connection, params map[string]Value) !i64 {
	value := o.value or { return if o.direction in [.next, .first] { 1 } else { -1 } }
	mut c := Compiler{
		conn:   conn
		params: params
	}

	return exact_integer('${o.direction.str().to_upper()} value', value.compile(mut c)!.run(mut conn,
		Row{}, params)!)
}

// move positions the cursor for a FETCH, and returns true if it's on a row.
// J is the result of FetchOrientation.number.
//
// While the cursor isn't on a row, it's between the row at position and the
// row after it (the first row when position is -1). position can also be
// rows.len, which is after the last row.
//
// The rows that the cursor can move to (Tt) are all of the rows for FIRST,
// LAST and ABSOLUTE, the rows after the cursor for NEXT and a positive
// RELATIVE, the rows before the cursor for PRIOR and a negative RELATIVE, or
// the current row (if there is one) for RELATIVE 0. The cursor moves to the
// K-th of those rows, where K counts from the end when J is negative. If
// there's no such row, the cursor is after the last row when it was moving
// forward (or LAST), otherwise it's before the first row. RELATIVE 0 doesn't
// move the cursor.
//
// ISO/IEC 9075-2:2016(E), 15.3, Determination of the current row of a cursor, General Rules, 6-9
fn (mut cursor Cursor) move(direction FetchDirection, j i64) bool {
	n := i64(cursor.rows.len)
	position := i64(cursor.position)
	// after is the first row after the cursor, and before is the last row before
	// it (each can be outside of the rows).
	after := position + 1
	before := if cursor.on_row {
		position - 1
	} else if position < n {
		position
	} else {
		n - 1
	}

	// first is the index of the first row of Tt, and count is the number of rows
	// in it.
	mut first := i64(0)
	mut count := n
	if direction in [.next, .relative] && j > 0 {
		first = if after < n { after } else { n }
		count = n - first
	} else if direction in [.prior, .relative] && j < 0 {
		count = before + 1
	} else if direction == .relative {
		return cursor.on_row
	}

	// k is the (1-based) row of Tt.
	k := if j < 0 { count + j + 1 } else { j }
	if k > 0 && k <= count {
		cursor.position = int(first + k - 1)
		cursor.on_row = true
		return true
	}

	cursor.on_row = false
	cursor.position = if direction in [.next, .last]
		|| (direction in [.absolute, .relative] && k > count) {
		cursor.rows.len
	} else {
		-1
	}

	return false
}

fn (stmt FetchStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN FETCH')
}

// fetch_statement compiles a <fetch statement> in a module, after FETCH. The
// values of the next row are assigned to the targets, like a <select
// statement: single row>.
fn (mut t ModuleTokens) fetch_statement(p ExternallyInvokedProcedure, cursors []ModuleCursor) !ModuleStatement {
	if t.accept('NEXT') {
		t.expect('FROM')!
	} else {
		t.accept('FROM')
	}
	cursor := t.module_cursor(p, cursors)!
	if cursor.statement != '' {
		return t.dynamic_fetch_statement(p, cursor)
	}
	t.expect('INTO')!
	targets := t.target_list(p, 'INTO')!
	t.end_of_statement(p)!

	// The number of targets must be the degree of the cursor.
	//
	// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, Syntax Rules, 9.b.i
	if cursor.degree >= 0 && cursor.degree != targets.len {
		are := if targets.len == 1 { 'is' } else { 'are' }
		return sqlstate_42601('procedure ${p.name}: cursor ${cursor.name} has ${cursor.degree} ${pluralize(cursor.degree, 'column')}, but there ${are} ${targets.len} ${pluralize(targets.len, 'target')}')
	}

	mut b := BoundParameters{
		sections: ['connection', 'target', 'cursor', 'fetch']
	}
	targets_c, assignments := bind_targets(targets, p, mut b)!
	call := 'vsql_m_fetch(SQLSTATE, ${cursor.index}, ${targets.len}, vsql_m_t)'

	return ModuleStatement{b.sections, b.used, cursor.begin('FETCH', 45) + targets_c +
		assign_targets(call, assignments)}
}
