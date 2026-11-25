module vsql

import time

// ISO/IEC 9075-2:2023, 11.33, <drop view statement>
//
// Destroy a view.

// The behavior is RESTRICT when it's not provided (the standard requires it).
// Nothing records which views read a view yet (#1264), so CASCADE and RESTRICT
// are the same.
struct DropViewStatement {
	table_name Identifier
	behavior   string // CASCADE or RESTRICT
}

fn (stmt DropViewStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	name := conn.resolve_schema_identifier(stmt.table_name)!
	check_writable_schema(name)!
	mut catalog := conn.catalog_for(name)

	// ISO/IEC 9075-2:2023, 11.33, <drop view statement>, Syntax Rules, 1 and 2
	view := catalog.storage.views[name.storage_id()] or {
		if name.storage_id() in catalog.storage.tables {
			return sqlstate_42601('${name} is a table, not a view')
		}

		return sqlstate_42p01('view', name.str()) // view does not exist
	}

	// ISO/IEC 9075-2:2023, 11.33, <drop view statement>, General Rules, 5
	catalog.storage.delete_view(view)!

	return new_result_msg('DROP VIEW 1', elapsed_parse, t.elapsed())
}

fn (stmt DropViewStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP VIEW')
}
