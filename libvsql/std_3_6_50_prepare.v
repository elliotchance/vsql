module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.50, Prepare
//
// Prepare a statement.
//
// The statement is parsed, and the tables and columns that it uses are found
// (see vsql.PreparedStmt.resolve_names), so a syntax error or a table that
// doesn't exist is raised by Prepare. Other errors are only raised by Execute
// (and ExecDirect raises them all when it's executed, like a statement that's
// executed directly). The data type of each dynamic parameter is determined from where it's used, and
// one that can't be determined (such as in "? + ?") is a syntax error (General
// Rules 7.c and 8). The IPD describes each dynamic parameter, and the IRD
// describes the result columns of a query if they can be known before it's
// executed.
//
// The cursor name of a query is generated when it's first needed (General Rules
// 12.b, see Stmt.get_cursor_name). A prepared statement stays valid in later
// SQL-transactions (General Rules 14, which is implementation-dependent).

@[export: 'SQLPrepare']
fn sql_prepare(statement_handle SQLInteger, statement_text &char, text_length SQLInteger) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	return prepare(mut stmt, statement_text, text_length) or { stmt.diag.error(err) }
}

fn prepare(mut stmt Stmt, statement_text &char, text_length SQLInteger) !i16 {
	stmt.invoke(false)!

	// - 2 to 7. The same as ExecDirect. An error here leaves any prepared
	// statement and cursor of S as they were.
	p := preparable_statement(mut stmt, statement_text, text_length)!
	mut prepared := prepare_statement(mut stmt, p)!
	db_resolve_names(mut prepared)!

	// - 10. Any prepared statement, cursor, select source and executed
	// statement associated with S are destroyed.
	stmt.prepared = none
	stmt.executed = false
	stmt.destroy_cursor()

	// - 11. P is prepared and the prepared statement is associated with S.
	stmt.prepared = prepared
	stmt.prepared_function = stmt.diag.dynamic_function
	stmt.prepared_function_code = stmt.diag.dynamic_function_code

	// - 13. The statement is described (see 5.5, "Implicit DESCRIBE USING
	// clause"), with a NULL for each dynamic parameter. A dynamic parameter
	// whose type isn't known until it has a value (see describe_parameters)
	// has the type of the IPD if it's set.
	mut conn := stmt_connection(stmt)!
	describe_parameters(stmt, prepared, conn.current_catalog_name())
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
