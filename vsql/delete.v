// delete.v contains the implementation for the DELETE statement.

module vsql

import time

fn execute_delete(mut c Connection, stmt DeleteStmt, params map[string]Value, elapsed_parse time.Duration, explain bool) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut table_name := stmt.table_name

	// TODO(elliotchance): This isn't really ideal. Replace with a proper
	//  identifier chain when we support that.
	if table_name.contains('.') {
		parts := table_name.split('.')

		if parts[0] !in c.storage.schemas {
			return sqlstate_3f000(parts[0]) // scheme does not exist
		}
	} else {
		table_name = 'PUBLIC.$table_name'
	}

	mut plan := create_plan(stmt, params, mut c)!

	if explain {
		return plan.explain(elapsed_parse)
	}

	mut rows := plan.execute([]Row{})!

	table := c.storage.get_table_by_name(table_name)!
	for mut row in rows {
		c.storage.delete_row(table, mut row)!
	}

	return new_result_msg('DELETE $rows.len', elapsed_parse, t.elapsed())
}
