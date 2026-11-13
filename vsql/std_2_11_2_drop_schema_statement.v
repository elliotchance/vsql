module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>
//
// Destroy a schema.

struct DropSchemaStatement {
	schema_name Identifier
	behavior    string // CASCADE or RESTRICT
	if_exists   bool   // V102-01, a schema that doesn't exist isn't an error
}

fn (stmt DropSchemaStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut catalog := conn.catalog_for(conn.resolve_catalog_identifier(stmt.schema_name)!)
	schema_name := stmt.schema_name.schema_name
	// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>, Syntax Rules, 3
	check_writable_schema(stmt.schema_name)!

	// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>, Syntax Rules, 2
	if schema_name !in catalog.storage.schemas {
		if stmt.if_exists {
			return new_result_msg('DROP SCHEMA 0', elapsed_parse, t.elapsed())
		}

		return sqlstate_3f000(schema_name) // schema does not exist
	}

	// Find all dependencies. A schema can only contain tables, views and
	// sequences, which are the only objects that RESTRICT needs to check for.
	//
	// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>, Syntax Rules, 4
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

	mut views := []View{}
	mut view_ids := catalog.storage.views.keys()
	view_ids.sort()
	for id in view_ids {
		view := catalog.storage.views[id] or { continue }
		if view.name.schema_name == schema_name {
			views << view
		}
	}

	if stmt.behavior == 'RESTRICT' && (table_names.len > 0 || sequences.len > 0 || views.len > 0) {
		return sqlstate_2bp01(schema_name)
	}

	// Each table is dropped like a DROP TABLE CASCADE, so the FOREIGN KEYs of
	// the tables in other schemas that reference the tables are dropped. Each
	// view is dropped like a DROP VIEW CASCADE. Then each sequence and the schema
	// itself are dropped.
	//
	// ISO/IEC 9075-2:2016(E), 11.2, <drop schema statement>, General Rules, 1, 2, 12 and 13
	catalog.storage.drop_foreign_keys_referencing(table_names)!

	// The views are dropped first, since a view in the schema can read a table
	// of the schema. Then the views of other schemas that read anything that
	// was dropped are dropped too.
	for view in views {
		catalog.storage.delete_view(view)!
	}

	for table_name in table_names {
		catalog.storage.delete_table(table_name, catalog.storage.table(table_name).tid)!
	}
	conn.drop_dependent_views(mut catalog, 'CASCADE', schema_name, map[string][]Column{})!

	for sequence in sequences {
		catalog.storage.delete_sequence(sequence.name, sequence.tid)!
	}

	catalog.storage.delete_schema(schema_name, catalog.storage.schemas[schema_name].tid)!

	return new_result_msg('DROP SCHEMA 1', elapsed_parse, t.elapsed())
}

fn (stmt DropSchemaStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP SCHEMA')
}
