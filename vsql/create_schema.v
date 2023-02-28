// create_schema.v contains the implementation for the CREATE SCHEMA statement.

module vsql

import time

fn execute_create_schema(mut c Connection, stmt CreateSchemaStmt, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	schema_name := stmt.schema_name.schema_name

	if schema_name in catalog.storage.schemas {
		return sqlstate_42p06(schema_name) // duplicate schema
	}

	catalog.storage.create_schema(schema_name)!

	return new_result_msg('CREATE SCHEMA 1', elapsed_parse, t.elapsed())
}
