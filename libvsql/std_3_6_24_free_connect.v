module main

// ISO/IEC 9075-3:2003(E), 6.24, FreeConnect
//
// Deallocate an SQL-connection.

@[export: 'SQLFreeConnect']
fn sql_free_connect(connection_handle SQLInteger) i16 {
	entry := enter(sql_handle_dbc, i64(connection_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.24, FreeConnect, General Rules, 1 and 2: the
	// same as FreeHandle of a CONNECTION HANDLE.
	return sql_free_handle(sql_handle_dbc, connection_handle)
}
