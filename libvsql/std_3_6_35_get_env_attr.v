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
	mut env := envs[i64(environment_handle)] or { return sql_invalid_handle }
	env.diag.clear()

	// - 3. If A is not one of the code values in Table 15, then an exception
	// condition is raised: CLI-specific condition — invalid attribute
	// identifier.
	if attribute != sql_attr_output_nts {
		return env.diag.error(cli_error('HY092', 'invalid attribute identifier'))
	}

	if value == unsafe { nil } {
		return env.diag.error(cli_error('HY009', 'invalid use of null pointer'))
	}

	// - 4. If A indicates NULL TERMINATION, then Value is set to 1 (one) if null
	// termination for E is True, or 0 (zero) if it's False.
	unsafe {
		*&SQLInteger(value) = if env.null_termination { sql_true } else { sql_false }
	}

	return sql_success
}
