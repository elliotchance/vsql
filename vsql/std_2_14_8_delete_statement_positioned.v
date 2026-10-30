module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.8, <delete statement: positioned>
//
// Delete a row of a table.

struct DeleteStatementPositioned {
	table_name  Identifier
	cursor_name string
}

fn (stmt DeleteStatementPositioned) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	mut cursor := conn.current_row(stmt.cursor_name, stmt.table_name)!
	result := DeleteStatementSearched{
		table_name: stmt.table_name
		current_of: cursor
	}.execute(mut conn, params, elapsed_parse)!

	// ISO/IEC 9075-2:2016(E), 15.5, Effect of a positioned delete, General Rule
	// 13
	cursor.on_row = false

	return result
}

fn (stmt DeleteStatementPositioned) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DELETE WHERE CURRENT OF')
}
