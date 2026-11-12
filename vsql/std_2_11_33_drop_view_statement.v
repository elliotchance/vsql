module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.33, <drop view statement>
//
// Destroy a view.

// The behavior is RESTRICT when it's not provided (the standard requires it).
// With RESTRICT, a view that another view reads can't be dropped. CASCADE drops
// those views too.
struct DropViewStatement {
	view_name Identifier
	behavior  string // CASCADE or RESTRICT
}

fn (stmt DropViewStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	// The view must exist, and be a view rather than a base table.
	//
	// ISO/IEC 9075-2:2016(E), 11.33, <drop view statement>, Syntax Rules, 1 and 2
	view_name := conn.resolve_schema_identifier(stmt.view_name)!
	check_writable_schema(view_name)!
	mut catalog := conn.catalog_for(view_name)
	view := catalog.storage.views[view_name.storage_id()] or {
		if view_name.storage_id() in catalog.storage.tables {
			return sqlstate_42601('${view_name} is a base table, not a view')
		}

		return sqlstate_42p01('view', view_name.str()) // view does not exist
	}

	// ISO/IEC 9075-2:2016(E), 11.33, <drop view statement>, General Rules, 5
	catalog.storage.delete_view(view)!
	conn.drop_dependent_views(mut catalog, stmt.behavior, view_name.str(), map[string][]Column{})!

	return new_result_msg('DROP VIEW 1', elapsed_parse, t.elapsed())
}

fn (stmt DropViewStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP VIEW')
}
