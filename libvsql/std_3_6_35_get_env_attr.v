module main

// ISO/IEC 9075-3:2003(E), 6.35, GetEnvAttr
//
// Get the value of an SQL-environment attribute.

// Codes from Table 15, "Codes used for environment attributes".
const sql_attr_output_nts = 10001

// Codes from Table 26, "Miscellaneous codes used in CLI".
const sql_false = 0
const sql_true = 1

@[export: 'SQLGetEnvAttr']
fn sql_get_env_attr(environment_handle SQLInteger, attribute SQLInteger, value voidptr, buffer_length SQLInteger, string_length &SQLInteger) i16 {
	entry := enter(sql_handle_env, i64(environment_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.35, GetEnvAttr, General Rules, 1. vsql never
	// has a skeleton SQL-environment.
	mut env := envs[i64(environment_handle)] or { return sql_invalid_handle }
	env.diag.clear()

	// ISO/IEC 9075-3:2003(E), 6.35, GetEnvAttr, General Rules, 2 and 3: the
	// attribute must be one of the codes in Table 15. There are no
	// implementation-defined environment attributes (General Rules, 5).
	if attribute != sql_attr_output_nts {
		return env.diag.error(cli_error('HY092', 'invalid attribute identifier'))
	}

	// ISO/IEC 9075-3:2003(E), 4.4.3, Null pointers
	if value == unsafe { nil } {
		return env.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// ISO/IEC 9075-3:2003(E), 6.35, GetEnvAttr, General Rules, 4
	unsafe {
		*&SQLInteger(value) = if env.null_termination { sql_true } else { sql_false }
	}

	return sql_success
}
