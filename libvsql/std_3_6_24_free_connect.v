module main

// ISO/IEC 9075-3:2003(E), 6.24, FreeConnect
//
// Deallocate an SQL-connection.

@[export: 'SQLFreeConnect']
fn sql_free_connect(connection_handle SQLInteger) i16 {
	// - 2. FreeHandle is implicitly invoked with HandleType indicating
	// CONNECTION HANDLE and with CH as the value of Handle.
	return sql_free_handle(sql_handle_dbc, connection_handle)
}
