module vsql

import time

// ISO/IEC 9075-2:2016(E), 11.31, <drop table statement>
//
// # Function
//
// Destroy a table.
//
// # Format
//~
//~ <drop table statement> /* Stmt */ ::=
//~     DROP TABLE <table name>   -> drop_table_statement

struct DropTableStatement {
	table_name Identifier
}

fn parse_drop_table_statement(table_name Identifier) !Stmt {
	return DropTableStatement{table_name}
}

fn (stmt DropTableStatement) execute(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	c.open_write_connection()!
	defer {
		c.release_write_connection()
	}

	mut catalog := c.catalog()
	table_name := c.resolve_table_identifier(stmt.table_name, false)!

	// TODO(elliotchance): Also delete rows. See
	//  https://github.com/elliotchance/vsql/issues/65.
	catalog.storage.delete_table(table_name.storage_id(), catalog.storage.tables[table_name.storage_id()].tid)!

	return new_result_msg('DROP TABLE 1', elapsed_parse, t.elapsed())
}

fn (stmt DropTableStatement) explain(mut c Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN DROP TABLE')
}
