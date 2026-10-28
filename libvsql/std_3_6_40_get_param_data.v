module main

// ISO/IEC 9075-3:2003(E), 6.40, GetParamData
//
// Retrieve the value of a dynamic output parameter.
//
// vsql doesn't have SQL-invoked procedures, so there are never dynamic output
// parameters (SQL_PARAM_MODE_OUT isn't supported by BindParameter). This always
// raises an exception condition: CLI-specific condition — optional feature not
// implemented.

@[export: 'SQLGetParamData']
fn sql_get_param_data(statement_handle SQLInteger, parameter_number i16, target_type i16, target_value voidptr, buffer_length SQLInteger, str_len_or_ind &SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.6.
	stmt.check_deferred() or { return stmt.diag.error(err) }

	return stmt.diag.error(cli_error('HYC00', 'optional feature not implemented: output parameters'))
}
