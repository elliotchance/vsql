module main

// ISO/IEC 9075-3:2003(E), 6.58, SetEnvAttr
//
// Set the value of an SQL-environment attribute.
//
// Value points to the attribute (see 5.1, "<CLI routine>").

@[export: 'SQLSetEnvAttr']
fn sql_set_env_attr(environment_handle SQLInteger, attribute SQLInteger, value voidptr, string_length SQLInteger) i16 {
	entry := enter(sql_handle_env, i64(environment_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.58, SetEnvAttr, General Rules, 1. vsql never
	// has a skeleton SQL-environment.
	h := i64(environment_handle)
	mut env := envs[h] or { return sql_invalid_handle }
	env.diag.clear()

	// ISO/IEC 9075-3:2003(E), 6.58, SetEnvAttr, General Rules, 2: it can't
	// have any allocated SQL-connections.
	for _, dbc in dbcs {
		if dbc.env == h {
			return env.diag.error(cli_error('HY011', 'attribute cannot be set now'))
		}
	}

	// ISO/IEC 9075-3:2003(E), 6.58, SetEnvAttr, General Rules, 3 and 4: the
	// attribute must be one of the codes in Table 15. There are no
	// implementation-defined environment attributes (General Rules, 6).
	if attribute != sql_attr_output_nts {
		return env.diag.error(cli_error('HY092', 'invalid attribute identifier'))
	}

	// ISO/IEC 9075-3:2003(E), 6.58, SetEnvAttr, General Rules, 5: NULL
	// TERMINATION must be TRUE or FALSE.
	v := read_integer(value) or { return env.diag.error(err) }
	env.null_termination = match v {
		sql_true { true }
		sql_false { false }
		else { return env.diag.error(cli_error('HY024', 'invalid attribute value')) }
	}

	return sql_success
}
