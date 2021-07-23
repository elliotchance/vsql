// drop_table.v contains the implementation for the DROP TABLE statement.

module vsql

fn (mut c Connection) drop_table(stmt DropTableStmt) ?Result {
	if stmt.table_name !in c.storage.tables {
		return sqlstate_42p01(stmt.table_name) // table does not exist
	}

	// TODO(elliotchance): Also delete rows.
	c.storage.delete_table(stmt.table_name) ?

	return new_result_msg('DROP TABLE 1')
}
