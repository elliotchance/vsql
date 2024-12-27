module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>
//
// Delete rows of a table.

struct DeleteStatementSearched {
	table_name Identifier
	where      ?BooleanValueExpression
}

fn (stmt DeleteStatementSearched) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut plan := create_plan(stmt, params, mut conn)!

	return plan.explain(elapsed_parse)
}

fn (stmt DeleteStatementSearched) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut plan := create_plan(stmt, params, mut conn)!
	mut rows := plan.execute([]Row{})!

	for mut row in rows {
		catalog.storage.delete_row(table_name.storage_id(), mut row)!
	}

	return new_result_msg('DELETE ${rows.len}', elapsed_parse, t.elapsed())
}
