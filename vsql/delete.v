// delete.v contains the implementation for the DELETE statement.

module vsql

import time

fn execute_delete(mut c Connection, stmt DeleteStmt, params map[string]Value, elapsed_parse time.Duration, explain bool) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut table_name := c.resolve_table_identifier(stmt.table_name, false)!
	mut plan := create_plan(stmt, params, mut c)!

	if explain {
		return plan.explain(elapsed_parse)
	}

	mut rows := plan.execute([]Row{})!

	for mut row in rows {
		c.storage.delete_row(table_name.id(), mut row)!
	}

	return new_result_msg('DELETE ${rows.len}', elapsed_parse, t.elapsed())
}
