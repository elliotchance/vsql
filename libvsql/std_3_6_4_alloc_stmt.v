module main

// ISO/IEC 9075-3:2003(E), 6.4, AllocStmt
//
// Allocate an SQL-statement and assign a handle to it.

@[export: 'SQLAllocStmt']
fn sql_alloc_stmt(connection_handle SQLInteger, statement_handle &SQLInteger) i16 {
	// - 2. AllocHandle is implicitly invoked with HandleType indicating
	// STATEMENT HANDLE, with CH as the value of InputHandle, and with
	// StatementHandle as OutputHandle.
	return sql_alloc_handle(sql_handle_stmt, connection_handle, statement_handle)
}
