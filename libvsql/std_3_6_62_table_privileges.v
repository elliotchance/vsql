module main

// ISO/IEC 9075-3:2003, 6.62, TablePrivileges
//
// Based on the specified selection criteria, return a result set that contains
// information about table privileges described by the Information Schema of the
// connected data source.
//
// vsql doesn't have privileges (or the TABLE_PRIVILEGES view), so once the
// arguments have been checked this always raises an exception condition:
// CLI-specific condition — optional feature not implemented. GetFunctions
// still reports that this routine isn't supported.

@[export: 'SQLTablePrivileges']
fn sql_table_privileges(statement_handle SQLInteger, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return table_privileges(stmt, catalog_name, name_length1, schema_name, name_length2,
		table_name, name_length3) or { stmt.diag.error(err) }
}

fn table_privileges(stmt &Stmt, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 10. The null pointers.
	check_metadata_id_args(stmt, [catalog_name, schema_name, table_name])!

	// - 8, 9, 11 to 14. The arguments.
	catalog_arg(catalog_name, name_length1)!
	catalog_arg(schema_name, name_length2)!
	catalog_arg(table_name, name_length3)!

	// - 5 to 7, 15 to 18. TABLE_PRIVILEGES_QUERY needs privileges.
	return cli_error('HYC00', 'optional feature not implemented: privileges')
}
