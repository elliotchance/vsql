module vsql

import time

// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>
//
// Delete rows of a table.

struct DeleteStatementSearched {
	table_name Identifier
	where      ?BooleanValueExpression
}

fn (stmt DeleteStatementSearched) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut plan := create_plan(stmt, params, mut conn)!

	return plan.explain(elapsed_parse)
}

fn (stmt DeleteStatementSearched) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	mut table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	mut plan := create_plan(stmt, params, mut conn)!
	mut rows := plan.execute([]Row{})!

	mut deleted := []Row{}
	for row in rows {
		// for_storage() here is important because it will strip the qualified
		// identifiers down to just their names used in storage.
		mut before := row.for_storage()
		catalog.storage.delete_row(table_name.storage_id(), mut before)!
		deleted << before
	}

	// A FOREIGN KEY is checked once all of the rows have been deleted, so a
	// DELETE can include rows that reference each other.
	_, time_zone := conn.now()
	catalog.storage.check_referencing_rows(catalog.storage.table(table_name.storage_id()),
		deleted, [], time_zone)!

	// ISO/IEC 9075-2:2016(E), 14.9, General Rules, 10
	if rows.len == 0 {
		conn.add_warning(sqlstate_02000())
	}

	return new_result_msg('DELETE ${rows.len}', elapsed_parse, t.elapsed())
}
