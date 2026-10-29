module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.6, <close statement>
//
// Close a standing cursor.

struct CloseStatement {
	name string
}

fn (stmt CloseStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	mut cursor := conn.open_cursor(stmt.name)!
	cursor.close()

	return new_result_msg('CLOSE', elapsed_parse, t.elapsed())
}

fn (stmt CloseStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CLOSE')
}

// close_statement compiles a <close statement> in a module, after CLOSE.
fn (mut t ModuleTokens) close_statement(p ExternallyInvokedProcedure, cursors []ModuleCursor) !ModuleStatement {
	cursor := t.module_cursor(p, cursors)!
	t.end_of_statement(p)!

	// - 20.22. A <dynamic close statement> closes a dynamic cursor.
	command := if cursor.statement == '' {
		begin('CLOSE CURSOR', 9)
	} else {
		begin('DYNAMIC CLOSE', 37)
	}

	return ModuleStatement{['connection', 'cursor', 'close'], [], command +
		'  vsql_m_close_cursor(SQLSTATE, ${cursor.index});\n'}
}
