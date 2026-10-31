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
	// ISO/IEC 9075-3:2003(E), 6.1, AllocConnect, General Rules, 1 and 2: the
	// same as AllocHandle of a CONNECTION HANDLE in the environment.
	return sql_alloc_handle(sql_handle_dbc, environment_handle, connection_handle)
}
