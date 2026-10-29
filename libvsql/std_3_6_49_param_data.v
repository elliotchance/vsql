module main

// ISO/IEC 9075-3:2003(E), 6.49, ParamData
//
// Process a deferred parameter value.
//
// After Execute (or ExecDirect) returns SQL_NEED_DATA, ParamData returns the
// DATA_POINTER of the deferred parameter in Value, and its value is given with
// PutData. Calling ParamData again moves to the next deferred parameter (and
// returns SQL_NEED_DATA), or executes the statement after the last one.

@[export: 'SQLParamData']
fn sql_param_data(statement_handle SQLInteger, value &voidptr) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.
	stmt.invoke(true) or { return stmt.diag.error(err) }

	return param_data(mut stmt, value) or {
		// The statement can't continue after an exception condition.
		if err !is NoData {
			stmt.cancel_deferred()
		}
		stmt.diag.error(err)
	}
}

fn param_data(mut stmt Stmt, value &voidptr) !i16 {
	// - 2. If there is no deferred parameter number associated with S, then an
	// exception condition is raised: CLI-specific condition — function sequence
	// error.
	dpn := stmt.deferred()
	if dpn == 0 {
		return cli_error('HY010', 'function sequence error')
	}
	apd := descs[stmt.apd] or { return cli_error('HY010', 'function sequence error') }
	ipd := descs[stmt.ipd] or { return cli_error('HY010', 'function sequence error') }

	// - 7. If there is no parameter value yet, Value is set to its DATA_POINTER
	// (which must not have been returned already: CLI-specific condition —
	// function sequence error) and it's needed from PutData.
	sv := stmt.deferred_value or {
		if stmt.deferred_data_pointer {
			return cli_error('HY010', 'function sequence error')
		}
		set_data_pointer(value, apd, dpn)
		stmt.deferred_data_pointer = true
		return sql_need_data
	}

	// - 11 to 14. The value is CAST ( SV AS TDT ).
	stmt.deferred_params['?${dpn}'] = cast_parameter(stmt, sv, ipd_type(ipd, dpn))!

	// - 16. If there's another deferred parameter, it becomes the deferred
	// parameter number, and its DATA_POINTER is returned in Value.
	stmt.deferred_parameters.delete(0)
	stmt.deferred_value = none
	if stmt.deferred_parameters.len > 0 {
		set_data_pointer(value, apd, stmt.deferred())
		return sql_need_data
	}

	// - 17. Otherwise, the statement is executed.
	mut prepared := stmt.deferred_stmt or { return cli_error('HY010', 'function sequence error') }
	params := stmt.deferred_params.clone()
	stmt.cancel_deferred()

	return run_statement(mut stmt, mut prepared, params)
}

fn set_data_pointer(value &voidptr, apd &Desc, pn int) {
	if value != unsafe { nil } {
		unsafe {
			*value = voidptr(apd.record_int(pn, sql_desc_data_pointer))
		}
	}
}
