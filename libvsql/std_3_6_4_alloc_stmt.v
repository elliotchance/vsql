module main

// ISO/IEC 9075-3:2003(E), 6.4, AllocStmt
//
// Allocate an SQL-statement and assign a handle to it.

@[export: 'SQLAllocStmt']
fn sql_alloc_stmt(connection_handle SQLInteger, statement_handle &SQLInteger) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.4, AllocStmt, General Rules, 1 and 2: the same
	// as AllocHandle of a STATEMENT HANDLE on the connection.
	return sql_alloc_handle(sql_handle_stmt, connection_handle, statement_handle)
}
