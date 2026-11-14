module main

// ISO/IEC 9075-3:2003, 6.40, GetParamData
//
// Retrieve the value of a dynamic output parameter.
//
// vsql doesn't have SQL-invoked procedures, so there are never dynamic output
// parameters (SQL_PARAM_MODE_OUT isn't supported by BindParameter), and the
// rules after General Rule 3 are never applied. GetFunctions still reports
// that this routine isn't supported.

@[export: 'SQLGetParamData']
fn sql_get_param_data(statement_handle SQLInteger, parameter_number i16, target_type i16, target_value voidptr, buffer_length SQLInteger, str_len_or_ind &SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	// - 2. If there is no executed statement associated with S, then an
	// exception condition is raised: CLI-specific condition — function
	// sequence error.
	//
	// - 3. If the executed statement isn't a <call statement>, then an
	// exception condition is raised: CLI-specific condition — function
	// sequence error. vsql doesn't have CALL, so it never is.
	return stmt.diag.error(cli_error('HY010', 'function sequence error'))
}
