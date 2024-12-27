module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>
//
// Destroy a schema.

struct DropSchemaStatement {
	schema_name Identifier
	behavior    string // CASCADE or RESTRICT
}

fn (stmt DropSchemaStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog()
	schema_name := stmt.schema_name.schema_name

	if schema_name !in catalog.storage.schemas {
		return sqlstate_3f000(schema_name) // schema does not exist
	}

	// Find all dependencies (which is just tables right now).
	mut table_names := []string{}
	for table_name, _ in catalog.storage.tables {
		if table_name.starts_with('${schema_name}.') {
			table_names << table_name
		}
	}

	if stmt.behavior == 'RESTRICT' && table_names.len > 0 {
		return sqlstate_2bp01(schema_name)
	}

	for table_name in table_names {
		catalog.storage.delete_table(table_name, catalog.storage.tables[table_name].tid)!
	}

	catalog.storage.delete_schema(schema_name, catalog.storage.schemas[schema_name].tid)!

	return new_result_msg('DROP SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt DropSchemaStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP SCHEMA')
}
