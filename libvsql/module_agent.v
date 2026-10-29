module main

// The SQL-agent of the SQL-client modules ("vsql module") that are linked into
// a program, see vsql_module_agent in libvsql.h. It's only set and used by the
// generated C.
__global module_agent = voidptr(0)

@[export: 'vsql_module_agent']
fn vsql_module_agent() &voidptr {
	return &module_agent
}
