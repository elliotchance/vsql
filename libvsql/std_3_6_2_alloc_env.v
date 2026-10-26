module main

// ISO/IEC 9075-3:2003(E), 6.2, AllocEnv
//
// Allocate an SQL-environment and assign a handle to it.

@[export: 'SQLAllocEnv']
fn sql_alloc_env(environment_handle &SQLInteger) i16 {
	// - 1. AllocHandle is implicitly invoked with HandleType indicating
	// ENVIRONMENT HANDLE, with zero as the value of InputHandle, and with
	// EnvironmentHandle as OutputHandle.
	return sql_alloc_handle(sql_handle_env, 0, environment_handle)
}
