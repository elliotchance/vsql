module vsql

import time

// ISO/IEC 9075-2:2023, 11.33, <drop view statement>
//
// Destroy a view.

// The behavior is RESTRICT when it's not provided (the standard requires it).
// With RESTRICT, a view that's used by another view can't be dropped. CASCADE
// drops those views too (see dependent_views).
//
// ISO/IEC 9075-2:2023, 11.33, <drop view statement>, Syntax Rules, 5 and 5.a
// ISO/IEC 9075-2:2023, 11.33, <drop view statement>, General Rules, 3.b and 3.b.i
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

	dependents := conn.dependent_views(catalog, [name.storage_id()], [])
	if dependents.len > 0 && stmt.behavior == 'RESTRICT' {
		return sqlstate_2bp01(name.str())
	}
	for dependent in dependents {
		catalog.storage.delete_view(dependent)!
	}

	// ISO/IEC 9075-2:2023, 11.33, <drop view statement>, General Rules, 5
	catalog.storage.delete_view(view)!

	return new_result_msg('DROP VIEW 1', elapsed_parse, t.elapsed())
}

// dependent_views are the views of a catalog that use any of the tables or views
// in tables, or any of the columns in columns (each by its storage_id, see
// ViewUsage), and the views that use those views, and so on. A view that can't
// be read doesn't use anything. They're found before anything is dropped,
// because a view can't be read once what it uses is gone.
//
// A view that uses another view depends on it (ISO/IEC 9075-1:2023, 6.3.4,
// Descriptors), so it's dropped with it. Dropping a table or a column of a table
// does the same, by revoking the privileges that the view needs (ISO/IEC
// 9075-2:2023, 12.7, <revoke statement>).
fn (mut conn Connection) dependent_views(catalog &CatalogConnection, tables []string, columns []string) []View {
	views := catalog.sorted_views()
	mut usages := map[string]ViewUsage{}
	for view in views {
		if usage := conn.view_usage_of(catalog.catalog_name, view) {
			usages[view.name.storage_id()] = usage
		}
	}

	mut used := tables.clone()
	mut dependents := []View{}
	mut found := true
	for found {
		found = false
		for view in views {
			id := view.name.storage_id()
			usage := usages[id] or { continue }
			if id !in used && (usage.tables.any(it.storage_id() in used)
				|| usage.columns.any(it.storage_id() in columns)) {
				used << id
				dependents << view
				found = true
			}
		}
	}

	return dependents
}

fn (stmt DropViewStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP VIEW')
}
