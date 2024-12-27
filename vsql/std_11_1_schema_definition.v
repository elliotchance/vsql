module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.1, <schema definition>
//
// Define a schema.

struct SchemaDefinition {
	schema_name Identifier
}

fn (stmt SchemaDefinition) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	schema_name := stmt.schema_name.schema_name

	if schema_name in catalog.storage.schemas {
		return sqlstate_42p06(schema_name) // duplicate schema
	}

	catalog.storage.create_schema(schema_name)!

	return new_result_msg('CREATE SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt SchemaDefinition) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN CREATE SCHEMA')
}
