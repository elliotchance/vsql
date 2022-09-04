// drop_schema.v contains the implementation for the DROP SCHEMA statement.

module vsql

import time

fn execute_drop_schema(mut c Connection, stmt DropSchemaStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	schema_name := stmt.schema_name.name

	if schema_name !in c.storage.schemas {
		return sqlstate_3f000(schema_name) // schema does not exist
	}

	// Find all dependencies (which is just tables right now).
	mut tables := []Table{}
	for table in c.storage.tables {
		if table.name.starts_with('${schema_name}.') && table.xid == 0 {
			tables << table
		}
	}

	if stmt.behavior == 'RESTRICT' && tables.len > 0 {
		return sqlstate_2bp01(schema_name)
	}

	for table in tables {
		c.storage.delete_table(table.name, table.tid)!
	}

	c.storage.delete_schema(schema_name, c.storage.schemas[schema_name].tid)!

	return new_result_msg('DROP SCHEMA 1', elapsed_parse, t.elapsed())
}
