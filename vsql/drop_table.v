// drop_table.v contains the implementation for the DROP TABLE statement.

module vsql

import time

fn execute_drop_table(mut c Connection, stmt DropTableStmt, elapsed_parse time.Duration) ?Result {
	t := start_timer()
	table_name := identifier_name(stmt.table_name)

	if table_name !in c.storage.tables {
		return sqlstate_42p01(table_name) // table does not exist
	}

	// TODO(elliotchance): Also delete rows.
	c.storage.delete_table(table_name) ?

	return new_result_msg('DROP TABLE 1', elapsed_parse, t.elapsed())
}
