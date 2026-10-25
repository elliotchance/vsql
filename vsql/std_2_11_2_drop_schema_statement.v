module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>
//
// Destroy a schema.

struct DropSchemaStatement {
	schema_name Identifier
	behavior    string // CASCADE or RESTRICT
}

fn (stmt DropSchemaStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog_for(conn.resolve_catalog_identifier(stmt.schema_name)!)
	schema_name := stmt.schema_name.schema_name
	check_writable_schema(stmt.schema_name)!

	if schema_name !in catalog.storage.schemas {
		return sqlstate_3f000(schema_name) // schema does not exist
	}

	// Find all dependencies (tables and sequences).
	mut table_names := []string{}
	for table_name, table in catalog.storage.tables {
		if table.name.schema_name == schema_name {
			table_names << table_name
		}
	}

	mut sequences := []Sequence{}
	for sequence in catalog.storage.sequences()! {
		if sequence.name.schema_name == schema_name {
			sequences << sequence
		}
	}

	if stmt.behavior == 'RESTRICT' && (table_names.len > 0 || sequences.len > 0) {
		return sqlstate_2bp01(schema_name)
	}

	// The FOREIGN KEYs of the tables in other schemas that reference the
	// tables are dropped.
	catalog.storage.drop_foreign_keys_referencing(table_names)!

	for table_name in table_names {
		catalog.storage.delete_table(table_name, catalog.storage.table(table_name).tid)!
	}

	for sequence in sequences {
		catalog.storage.delete_sequence(sequence.name, sequence.tid)!
	}

	catalog.storage.delete_schema(schema_name, catalog.storage.schemas[schema_name].tid)!

	return new_result_msg('DROP SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt DropSchemaStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP SCHEMA')
}
