// create_table.v contains the implementation for the CREATE TABLE statement.

module vdb

fn (mut db Vdb) create_table(stmt CreateTableStmt) ?Result {
	if stmt.table_name in db.storage.tables {
		return sqlstate_42p07(stmt.table_name) // duplicate table
	}

	db.storage.create_table(stmt.table_name, stmt.columns) ?

	return new_result_msg('CREATE TABLE 1')
}
