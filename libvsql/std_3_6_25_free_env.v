module main

// ISO/IEC 9075-3:2003(E), 6.25, FreeEnv
//
// Deallocate an SQL-environment.

@[export: 'SQLFreeEnv']
fn sql_free_env(environment_handle SQLInteger) i16 {
	entry := enter(sql_handle_env, i64(environment_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.25, FreeEnv, General Rules, 1 and 2: the same
	// as FreeHandle of an ENVIRONMENT HANDLE.
	return sql_free_handle(sql_handle_env, environment_handle)
}
