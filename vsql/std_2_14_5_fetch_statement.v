module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>
//
// Position a standing cursor on a specified row of the standing cursor's result
// set and retrieve values from that row.

// The row is returned as the result, instead of being assigned to a <fetch
// target list> (V004-03).
struct FetchStatement {
	name string
}

fn (stmt FetchStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut cursor := conn.open_cursor(stmt.name)!
	cursor.fetched = true

	// Only NEXT is supported, so the cursor moves to the next row, or after the
	// last row with no data.
	//
	// ISO/IEC 9075-2:2016(E), 14.5, <fetch statement>, General Rules, 3 and 4
	// ISO/IEC 9075-2:2016(E), 15.3, Determination of the current row of a cursor, General Rules, 5.b, 7.b, 8 and 9
	if cursor.position < cursor.rows.len {
		cursor.position++
	}
	cursor.on_row = cursor.position < cursor.rows.len
	if !cursor.on_row {
		conn.add_warning(sqlstate_02000())

		return new_result(cursor.columns, []Row{}, elapsed_parse, t.elapsed())
	}

	return new_result(cursor.columns, [cursor.rows[cursor.position]], elapsed_parse,
		t.elapsed())
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

	return ModuleStatement{b.sections, b.used, begin('FETCH', 45) + targets_c +
		assign_targets(call, assignments)}
}
