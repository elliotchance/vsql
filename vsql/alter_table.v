// alter_table.v contains the implementation for the ALTER TABLE statement.

module vsql

import time

fn execute_alter_table(mut c Connection, stmt AlterTableStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut table_name := stmt.table_name.name

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

	if table_name !in c.storage.tables {
		return sqlstate_42p01(table_name) // table does not exist
	}

	table := c.storage.tables[table_name]
	column_name := stmt.action.column_definition.column_name.name
	if column_name in table.column_names() {
		return sqlstate_42s21(column_name) // column already exists
	}

	c.storage.add_column(table_name, stmt.action.column_definition) !

	return new_result_msg('ALTER TABLE 1', elapsed_parse, t.elapsed())
}
