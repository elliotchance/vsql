module vsql

import time

// ISO/IEC 9075-2:2023, 14.13, <update statement: positioned>
//
// Update a row of a table.

struct UpdateStatementPositioned {
	table_name Identifier
	// correlation_name is empty if there isn't one.
	correlation_name Identifier
	set              []SetClause
	cursor_name      string
}

fn (stmt UpdateStatementPositioned) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	cursor := conn.current_row(stmt.cursor_name, stmt.table_name)!

	// Each column that's set can't be used by a sort key, and must be in the
	// <column name list> of FOR UPDATE, if there is one.
	//
	// ISO/IEC 9075-2:2023, 14.13, <update statement: positioned>, Syntax Rules, 13 and 14
	for clause in stmt.set {
		if clause.column_name in cursor.sort_columns {
			return sqlstate_42601('column ${clause.column_name} is used by a sort key of cursor ${cursor.name}')
		}
		if cursor.update_columns.len > 0 && clause.column_name !in cursor.update_columns {
			return sqlstate_42601('column ${clause.column_name} is not updatable by cursor ${cursor.name}')
		}
	}

	// The cursor stays on its current row.
	//
	// ISO/IEC 9075-2:2023, 15.7, Effect of a positioned update, General Rules, 12
	return UpdateStatementSearched{
		table_name:       stmt.table_name
		correlation_name: stmt.correlation_name
		set:              stmt.set
		current_of:       cursor
	}.execute(mut conn, params, elapsed_parse)
}

fn (stmt UpdateStatementPositioned) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN UPDATE WHERE CURRENT OF')
}
