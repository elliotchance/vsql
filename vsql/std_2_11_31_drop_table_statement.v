module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>
//
// Destroy a table.

// The behavior is RESTRICT when it's not provided (the standard requires it).
// With RESTRICT, a table that's referenced by a FOREIGN KEY of another table, or
// read by a view, can't be dropped. CASCADE drops those FOREIGN KEYs instead,
// which is what revoking the REFERENCES privilege on the table would do, and
// the views (see Connection.drop_dependent_views).
//
// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>, Syntax Rules, 7.d
// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>, General Rules, 3
struct DropTableStatement {
	table_name Identifier
	behavior   string // CASCADE or RESTRICT
	if_exists  bool   // V104-02, a table that doesn't exist isn't an error
}

fn (stmt DropTableStatement) execute(mut conn Connection, _ map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	conn.open_write_connection()!
	defer {
		conn.release_write_connection()
	}

	// The table must exist, and be a base table (not a table of the
	// INFORMATION_SCHEMA).
	//
	// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>, Syntax Rules, 2 and 3
	table_name := conn.resolve_table_identifier(stmt.table_name, false) or {
		// A table can't exist in a schema that doesn't exist. Any other error,
		// such as the table being read-only or in a catalog that doesn't exist,
		// is the same as without IF EXISTS.
		if stmt.if_exists && (err is SQLState42P01 || err is SQLState3F000) {
			return new_result_msg('DROP TABLE 0', elapsed_parse, t.elapsed())
		}

		return err
	}
	mut catalog := conn.catalog_for(table_name)
	table := catalog.storage.table(table_name.storage_id())
	if stmt.behavior == 'RESTRICT' && catalog.storage.referencing_tables(table).len > 0 {
		return sqlstate_2bp01(table_name.str())
	}
	catalog.storage.drop_foreign_keys_referencing([table_name.storage_id()])!

	// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>, General Rules, 6
	catalog.storage.delete_table(table_name.storage_id(),
		catalog.storage.table(table_name.storage_id()).tid)!
	conn.drop_dependent_views(mut catalog, stmt.behavior, table_name.str(), map[string][]Column{})!

	return new_result_msg('DROP TABLE 1', elapsed_parse, t.elapsed())
}

fn (stmt DropTableStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP TABLE')
}
