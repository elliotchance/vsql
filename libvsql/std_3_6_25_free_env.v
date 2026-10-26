module main

// ISO/IEC 9075-3:2003(E), 6.25, FreeEnv
//
// Deallocate an SQL-environment.

@[export: 'SQLFreeEnv']
fn sql_free_env(environment_handle SQLInteger) i16 {
	// - 2. FreeHandle is implicitly invoked with HandleType indicating
	// ENVIRONMENT HANDLE and with EH as the value of Handle.
	return sql_free_handle(sql_handle_env, environment_handle)
}
