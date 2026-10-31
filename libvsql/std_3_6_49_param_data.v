module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.49, ParamData
//
// Process a deferred parameter value.
//
// After Execute (or ExecDirect) returns SQL_NEED_DATA, ParamData returns the
// DATA_POINTER of the deferred parameter in Value, and its value is given with
// PutData. Calling ParamData again moves to the next deferred parameter (and
// returns SQL_NEED_DATA), or executes the statement after the last one.
//
// The deferred parameters are found when the statement is executed (General
// Rules 3 to 5, see 5.6, "Implicit EXECUTE USING and OPEN USING clauses",
// General Rules 4.j). There's no maximum length for a character string, and
// there are no large objects or locators (General Rules 11.a.i.1.B, 11.a.i.2,
// 11.a.i.3 and 14.a). The data type of a dynamic parameter isn't determined, so
// there's no second cast (General Rules 14.b.ii and 14.b.iii), which is #649.
// An exception condition also removes the deferred parameter number, which
// is #750.

@[export: 'SQLParamData']
fn sql_param_data(statement_handle SQLInteger, value &voidptr) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
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

	// - 11.a.i.1.A. A character string is the characters wholly contained in
	// its octets, so it doesn't end with part of a character (PutData checked
	// that the rest is valid UTF-8).
	v := if sv.typ.typ == .is_varchar && !sv.is_null {
		vsql.new_varchar_value(whole_characters(sv.string_value()))
	} else {
		sv
	}

	// - 11 to 14. The value is CAST ( V AS TDT ).
	stmt.deferred_params['?${dpn}'] = cast_parameter(stmt, v, ipd_type(ipd, dpn))!

	// - 16. If there's another deferred parameter, it becomes the deferred
	// parameter number, and its DATA_POINTER is returned in Value.
	stmt.deferred_parameters.delete(0)
	stmt.deferred_value = none
	if stmt.deferred_parameters.len > 0 {
		set_data_pointer(value, apd, stmt.deferred())
		return sql_need_data
	}

	// - 17. Otherwise, the statement is executed, the same as ExecDirect (see
	// run_statement).
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
