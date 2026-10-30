module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.52, PutData
//
// Provide a deferred parameter value.
//
// A string can be given in pieces, by calling PutData again for the same
// parameter.

@[export: 'SQLPutData']
fn sql_put_data(statement_handle SQLInteger, data voidptr, str_len_or_ind SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules,
	// 3.b.i
	stmt.invoke(true) or { return stmt.diag.error(err) }

	return put_data(mut stmt, data, i64(str_len_or_ind)) or { stmt.diag.error(err) }
}

fn put_data(mut stmt Stmt, data voidptr, iv i64) !i16 {
	// - 2, 3. There must be a deferred parameter number, and ParamData must
	// have returned its DATA_POINTER, otherwise an exception condition is
	// raised: CLI-specific condition — function sequence error.
	dpn := stmt.deferred()
	if dpn == 0 || !stmt.deferred_data_pointer {
		return cli_error('HY010', 'function sequence error')
	}
	apd := descs[stmt.apd] or { return cli_error('HY010', 'function sequence error') }
	ipd := descs[stmt.ipd] or { return cli_error('HY010', 'function sequence error') }

	// - 5. PT is the type of the parameter in the APD (where DEFAULT is the type
	// from the IPD).
	typ := application_type(apd, ipd, dpn) or { return using_clause_error() }

	// - 7. If there is a parameter value associated with DPN and PT does not
	// indicate CHARACTER, then an exception is raised: CLI-specific condition —
	// non-string data cannot be sent in pieces.
	if stmt.deferred_value != none && typ != .is_varchar {
		return cli_error('HY019', 'non-string data cannot be sent in pieces')
	}

	// - 8. V is the null value, a string of IV octets (or SQL_NTS), or the value
	// of Data.
	v := if iv == sql_null_data {
		vsql.new_null_value(.is_varchar)
	} else {
		if data == unsafe { nil } {
			return cli_error('HY009', 'invalid use of null pointer')
		}
		read_c_value(typ, data, iv)!
	}

	// - 10, 11. The value is concatenated to the value so far, which can't be
	// (or be followed by) a null value: CLI-specific condition — attempt to
	// concatenate a null value.
	pv := stmt.deferred_value or {
		stmt.deferred_value = v
		return sql_success
	}
	if v.is_null || pv.is_null {
		stmt.cancel_deferred()
		return cli_error('HY020', 'attempt to concatenate a null value')
	}
	stmt.deferred_value = vsql.new_varchar_value(pv.str() + v.str())

	return sql_success
}
