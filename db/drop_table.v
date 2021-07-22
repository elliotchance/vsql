// drop_table.v contains the implementation for the DROP TABLE statement.

module vdb

fn (mut db Vdb) drop_table(stmt DropTableStmt) ?Result {
	if stmt.table_name !in db.storage.tables {
		return sqlstate_42p01(stmt.table_name) // table does not exist
	}

	// TODO(elliotchance): Also delete rows.
	db.storage.delete_table(stmt.table_name) ?

	return new_result_msg('DROP TABLE 1')
}
