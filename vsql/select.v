// select.v contains the implementation for the SELECT statement.

module vsql

import time

fn execute_select(mut c Connection, stmt QueryExpression, params map[string]Value, elapsed_parse time.Duration, explain bool) !Result {
	t := start_timer()

	c.open_read_connection()!
	defer {
		c.release_read_connection()
	}

	mut plan := create_plan(stmt, params, mut c)!

	if explain {
		return plan.explain(elapsed_parse)
	}

	rows := plan.execute([]Row{})!

	return new_result(plan.columns(), rows, elapsed_parse, t.elapsed())
}
