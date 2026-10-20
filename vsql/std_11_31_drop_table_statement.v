module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>
//
// Destroy a table.

struct DropTableStatement {
	table_name Identifier
}

fn (stmt DropTableStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)

	catalog.storage.delete_table(table_name.storage_id(),
		catalog.storage.tables[table_name.storage_id()].tid)!

	return new_result_msg('DROP TABLE 1', elapsed_parse, t.elapsed())
}

fn (stmt DropTableStatement) explain(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP TABLE')
}
