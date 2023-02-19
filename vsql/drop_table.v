// drop_table.v contains the implementation for the DROP TABLE statement.

module vsql

import time

fn execute_drop_table(mut c Connection, stmt DropTableStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	table_name := c.resolve_table_identifier(stmt.table_name, false)!

	// TODO(elliotchance): Also delete rows. See
	//  https://github.com/elliotchance/vsql/issues/65.
	catalog.storage.delete_table(table_name.storage_id(), catalog.storage.tables[table_name.storage_id()].tid)!

	return new_result_msg('DROP TABLE 1', elapsed_parse, t.elapsed())
}
