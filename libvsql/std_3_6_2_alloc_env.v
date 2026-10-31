module main

// ISO/IEC 9075-3:2003(E), 6.2, AllocEnv
//
// Allocate an SQL-environment and assign a handle to it.

@[export: 'SQLAllocEnv']
fn sql_alloc_env(environment_handle &SQLInteger) i16 {
	entry := enter(0, 0)
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.2, AllocEnv, General Rules, 1: the same as
	// AllocHandle of an ENVIRONMENT HANDLE, with no input handle.
	return sql_alloc_handle(sql_handle_env, 0, environment_handle)
}
