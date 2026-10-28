module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.50, Prepare
//
// Prepare a statement.
//
// The statement is parsed, so a syntax error is raised by Prepare, but other
// errors (such as a table that doesn't exist) are only raised by Execute. The
// IRD describes the result columns of a query if they can be known before
// it's executed (the data type of a dynamic parameter isn't known until it has
// a value, so the IPD type is used if it's set, and otherwise it may only be
// known after the statement is executed).

@[export: 'SQLPrepare']
fn sql_prepare(statement_handle SQLInteger, statement_text &char, text_length SQLInteger) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return prepare(mut stmt, statement_text, text_length) or { stmt.diag.error(err) }
}

fn prepare(mut stmt Stmt, statement_text &char, text_length SQLInteger) !i16 {
	stmt.check_deferred()!

	// - 2 to 7. The same as ExecDirect.
	p := preparable_statement(mut stmt, statement_text, text_length)!

	// - 10. Any prepared statement, cursor, select source and executed
	// statement associated with S are destroyed.
	stmt.prepared = none
	stmt.executed = false
	stmt.close_cursor()

	// - 11. P is prepared and the prepared statement is associated with S.
	mut conn := stmt_connection(stmt)!
	mut prepared := &vsql.PreparedStmt{
		...conn.prepare(p)!
	}
	stmt.prepared = prepared
	stmt.prepared_function = stmt.diag.dynamic_function
	stmt.prepared_function_code = stmt.diag.dynamic_function_code

	// - 13. The statement is described (see 5.5, "Implicit DESCRIBE USING
	// clause"), with a NULL for each dynamic parameter.
	ipd := descs[stmt.ipd] or { return cli_error('HY010', 'function sequence error') }
	mut params := map[string]vsql.Value{}
	for i in 1 .. prepared.dynamic_parameter_count() + 1 {
		typ := if i <= ipd.count() && ipd.is_consistent(ipd.records[i - 1]) {
			ipd_type(ipd, i)
		} else {
			vsql.Type{
				typ: .is_varchar
			}
		}
		params['?${i}'] = vsql.new_null_value(typ.typ)
	}
	columns := prepared.columns(params) or { []vsql.Column{} }
	describe(stmt, mut conn, columns)

	return sql_success
}
