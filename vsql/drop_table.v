// drop_table.v contains the implementation for the DROP TABLE statement.

module vsql

import time

fn execute_drop_table(mut c Connection, stmt DropTableStmt, elapsed_parse time.Duration) !Result {
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

	table := c.storage.get_table_by_name(table_name)!

	// TODO(elliotchance): Also delete rows. See
	//  https://github.com/elliotchance/vsql/issues/65.
	c.storage.delete_table(table.id, table.tid)!

	return new_result_msg('DROP TABLE 1', elapsed_parse, t.elapsed())
}
