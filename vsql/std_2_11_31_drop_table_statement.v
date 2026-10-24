module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>
//
// Destroy a table.

// The behavior is RESTRICT when it's not provided (the standard requires it).
// Nothing can depend on a table yet (such as a view or a foreign key), so
// CASCADE and RESTRICT are the same.
struct DropTableStatement {
	table_name Identifier
	behavior   string // CASCADE or RESTRICT
}

fn (stmt DropTableStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)

	catalog.storage.delete_table(table_name.storage_id(),
		catalog.storage.table(table_name.storage_id()).tid)!

	return new_result_msg('DROP TABLE 1', elapsed_parse, t.elapsed())
}

fn (stmt DropTableStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP TABLE')
}
