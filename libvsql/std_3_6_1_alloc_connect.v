module main

// ISO/IEC 9075-3:2003(E), 6.1, AllocConnect
//
// Allocate an SQL-connection and assign a handle to it.

@[export: 'SQLAllocConnect']
fn sql_alloc_connect(environment_handle SQLInteger, connection_handle &SQLInteger) i16 {
	entry := enter(sql_handle_env, i64(environment_handle))
	defer {
		entry.leave()
	}
	// - 2. AllocHandle is implicitly invoked with HandleType indicating
	// CONNECTION HANDLE, with EH as the value of InputHandle and with
	// ConnectionHandle as OutputHandle.
	return sql_alloc_handle(sql_handle_dbc, environment_handle, connection_handle)
}
