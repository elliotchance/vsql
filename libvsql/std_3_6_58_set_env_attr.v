module main

// ISO/IEC 9075-3:2003(E), 6.58, SetEnvAttr
//
// Set the value of an SQL-environment attribute.
//
// Value points to the attribute (see 5.1, "<CLI routine>").

@[export: 'SQLSetEnvAttr']
fn sql_set_env_attr(environment_handle SQLInteger, attribute SQLInteger, value voidptr, string_length SQLInteger) i16 {
	h := i64(environment_handle)
	mut env := envs[h] or { return sql_invalid_handle }
	env.diag.clear()

	// - 2. If there are any allocated SQL-connections associated with E, then
	// an exception condition is raised: CLI-specific condition — attribute
	// cannot be set now.
	for _, dbc in dbcs {
		if dbc.env == h {
			return env.diag.error(cli_error('HY011', 'attribute cannot be set now'))
		}
	}

	// - 4. If A is not one of the code values in Table 15, then an exception
	// condition is raised: CLI-specific condition — invalid attribute
	// identifier.
	if attribute != sql_attr_output_nts {
		return env.diag.error(cli_error('HY092', 'invalid attribute identifier'))
	}

	// - 5. If A indicates NULL TERMINATION, then Value must be TRUE or FALSE,
	// otherwise an exception condition is raised: CLI-specific condition —
	// invalid attribute value.
	v := read_integer(value) or { return env.diag.error(err) }
	env.null_termination = match v {
		sql_true { true }
		sql_false { false }
		else { return env.diag.error(cli_error('HY024', 'invalid attribute value')) }
	}

	return sql_success
}
