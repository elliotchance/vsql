module main

// ISO/IEC 9075-3:2003(E), 6.51, PrimaryKeys
//
// Return a result set that contains a list of the column names that comprise
// the primary key for a single specified table stored in the information
// schemas of the connected data source.

// primary_keys_query is PRIMARY_KEYS_QUERY (General Rules 5 to 10).
const primary_keys_query = "(SELECT
		CAST(K.TABLE_CATALOG AS VARCHAR(128)) AS TABLE_CAT,
		CAST(K.TABLE_SCHEMA AS VARCHAR(128)) AS TABLE_SCHEM,
		CAST(K.TABLE_NAME AS VARCHAR(128)) AS TABLE_NAME,
		CAST(K.COLUMN_NAME AS VARCHAR(128)) AS COLUMN_NAME,
		CAST(K.ORDINAL_POSITION AS SMALLINT) AS ORDINAL_POSITION,
		CAST(K.CONSTRAINT_NAME AS VARCHAR(128)) AS PK_NAME
	FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS K
	JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS T
		ON T.CONSTRAINT_CATALOG = K.CONSTRAINT_CATALOG
		AND T.CONSTRAINT_SCHEMA = K.CONSTRAINT_SCHEMA
		AND T.CONSTRAINT_NAME = K.CONSTRAINT_NAME
	WHERE T.CONSTRAINT_TYPE = 'PRIMARY KEY') AS PRIMARY_KEYS_QUERY"

@[export: 'SQLPrimaryKeys']
fn sql_primary_keys(statement_handle SQLInteger, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return primary_keys(mut stmt, catalog_name, name_length1, schema_name, name_length2,
		table_name, name_length3) or { stmt.diag.error(err) }
}

fn primary_keys(mut stmt Stmt, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 11 to 18. The arguments. The table must be given (it's not a pattern).
	cat := catalog_arg(catalog_name, name_length1)!
	sch := catalog_arg(schema_name, name_length2)!
	tbl := catalog_arg(table_name, name_length3)!
	check_metadata_id_args(stmt, [cat, sch])!
	if tbl.is_null {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 19 to 22. ExecDirect is implicitly invoked.
	pred := name_predicate(stmt, 'TABLE_CAT', cat, false) +
		name_predicate(stmt, 'TABLE_SCHEM', sch, false) +
		name_predicate(stmt, 'TABLE_NAME', tbl, false)

	return exec_direct_text(mut stmt, 'SELECT * FROM ${primary_keys_query} WHERE ${pred}1 = 1 ORDER BY TABLE_CAT, TABLE_SCHEM, TABLE_NAME, ORDINAL_POSITION')
}
