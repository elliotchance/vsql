// delete.v contains the implementation for the DELETE statement.

module vsql

import time

fn execute_delete(mut c Connection, stmt DeleteStmt, params map[string]Value, elapsed_parse time.Duration, explain bool) ?Result {
	t := start_timer()
	plan := create_plan(stmt, params, c) ?

	if explain {
		return plan.explain(elapsed_parse)
	}

	rows := plan.execute([]Row{}) ?

	table_name := identifier_name(stmt.table_name)
	for row in rows {
		c.storage.delete_row(table_name, row) ?
	}

	return new_result_msg('DELETE $rows.len', elapsed_parse, t.elapsed())
}
