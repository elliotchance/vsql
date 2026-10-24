module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.10, <alter table statement>
//
// Change the definition of a table.

// ADD COLUMN is the only <alter table action> that's supported.
struct AlterTableStatement {
	table_name Identifier
	action     AddColumnDefinition
}

fn (stmt AlterTableStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	table_name := conn.resolve_table_identifier(stmt.table_name, false)!
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())

	stmt.action.execute(mut conn, mut catalog, table, params)!

	return new_result_msg('ALTER TABLE 1', elapsed_parse, t.elapsed())
}

fn (stmt AlterTableStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN ALTER TABLE')
}
