// create_table.v contains the implementation for the CREATE TABLE statement.

module vsql

import time

// TODO(elliotchance): A table is allowed to have zero columns.

fn execute_create_table(mut c Connection, stmt CreateTableStmt, elapsed_parse time.Duration) ?Result {
	t := start_timer()
	table_name := identifier_name(stmt.table_name)

	if table_name in c.storage.tables {
		return sqlstate_42p07(table_name) // duplicate table
	}

	mut columns := []Column{cap: stmt.columns.len}
	for column in stmt.columns {
		column_name := identifier_name(column.name)

		columns << Column{column_name, column.typ, column.not_null}
	}

	c.storage.create_table(table_name, columns) ?

	return new_result_msg('CREATE TABLE 1', elapsed_parse, t.elapsed())
}
