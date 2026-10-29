module main

// ISO/IEC 9075-3:2003(E), 6.10, ColumnPrivileges
//
// Based on the specified selection criteria, return a result set that contains
// information about column privileges defined by the Information Schema of the
// connected data source.
//
// vsql doesn't have privileges (or the COLUMN_PRIVILEGES view), so this always
// raises an exception condition: CLI-specific condition — optional feature not
// implemented.

@[export: 'SQLColumnPrivileges']
fn sql_column_privileges(statement_handle SQLInteger, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, column_name &char, name_length4 i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()

	// See 5.2, "<CLI routine> invocation", General Rule 3.b.i.6.
	stmt.check_deferred() or { return stmt.diag.error(err) }

	return stmt.diag.error(cli_error('HYC00', 'optional feature not implemented: privileges'))
}
