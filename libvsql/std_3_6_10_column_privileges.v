module main

// ISO/IEC 9075-3:2003(E), 6.10, ColumnPrivileges
//
// Based on the specified selection criteria, return a result set that contains
// information about column privileges defined by the Information Schema of the
// connected data source.
//
// vsql doesn't have privileges (or the COLUMN_PRIVILEGES view), so once the
// arguments have been checked this always raises an exception condition:
// CLI-specific condition — optional feature not implemented. GetFunctions
// still reports that this routine isn't supported.

@[export: 'SQLColumnPrivileges']
fn sql_column_privileges(statement_handle SQLInteger, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, column_name &char, name_length4 i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return column_privileges(stmt, catalog_name, name_length1, schema_name, name_length2,
		table_name, name_length3, column_name, name_length4) or { stmt.diag.error(err) }
}

fn column_privileges(stmt &Stmt, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, column_name &char, name_length4 i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 10, 11. The null pointers.
	check_metadata_id_args(stmt, [catalog_name, schema_name, column_name])!
	check_table_name_arg(table_name)!

	// - 8, 9, 12 to 16. The arguments.
	catalog_arg(catalog_name, name_length1)!
	catalog_arg(schema_name, name_length2)!
	catalog_arg(table_name, name_length3)!
	catalog_arg(column_name, name_length4)!

	// - 5 to 7, 17 to 20. COLUMN_PRIVILEGES_QUERY needs privileges.
	return cli_error('HYC00', 'optional feature not implemented: privileges')
}
