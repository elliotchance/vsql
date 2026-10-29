module main

// ISO/IEC 9075-3:2003(E), 6.63, Tables
//
// Based on the specified selection criteria, return a result set that contains
// information about tables described by the Information Schema of the
// connected data source.
//
// A base table is a 'TABLE' and a view of the INFORMATION_SCHEMA is a 'SYSTEM
// TABLE'. vsql doesn't have other views, and virtual tables registered with
// the V API aren't described by INFORMATION_SCHEMA.TABLES, so they aren't
// returned.

// tables_query is TABLES_QUERY (General Rules 5 to 7).
const tables_query = "(SELECT
		CAST(TABLE_CATALOG AS VARCHAR(128)) AS TABLE_CAT,
		CAST(TABLE_SCHEMA AS VARCHAR(128)) AS TABLE_SCHEM,
		CAST(TABLE_NAME AS VARCHAR(128)) AS TABLE_NAME,
		CAST(CASE
			WHEN TABLE_TYPE = 'BASE TABLE' THEN 'TABLE'
			WHEN TABLE_SCHEMA = 'INFORMATION_SCHEMA' THEN 'SYSTEM TABLE'
			ELSE TABLE_TYPE
		END AS VARCHAR(254)) AS TABLE_TYPE,
		CAST(NULL AS VARCHAR(254)) AS REMARKS,
		CAST(SELF_REFERENCING_COLUMN_NAME AS VARCHAR(128)) AS SELF_REF_COLUMN,
		CAST(REFERENCE_GENERATION AS VARCHAR(254)) AS REF_GENERATION,
		CAST(USER_DEFINED_TYPE_CATALOG AS VARCHAR(128)) AS UDT_CAT,
		CAST(USER_DEFINED_TYPE_SCHEMA AS VARCHAR(128)) AS UDT_SCHEM,
		CAST(USER_DEFINED_TYPE_NAME AS VARCHAR(128)) AS UDT_NAME
	FROM INFORMATION_SCHEMA.TABLES) AS TABLES_QUERY"

@[export: 'SQLTables']
fn sql_tables(statement_handle SQLInteger, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, table_type &char, name_length4 i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return tables(mut stmt, catalog_name, name_length1, schema_name, name_length2, table_name,
		name_length3, table_type, name_length4) or { stmt.diag.error(err) }
}

fn tables(mut stmt Stmt, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, table_type &char, name_length4 i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 10 to 15. The arguments.
	cat := catalog_arg(catalog_name, name_length1)!
	sch := catalog_arg(schema_name, name_length2)!
	tbl := catalog_arg(table_name, name_length3)!
	typ := catalog_arg(table_type, name_length4)!
	check_metadata_id_args(stmt, [cat, sch, tbl])!

	null := 'CAST(NULL AS VARCHAR(128))'
	null254 := 'CAST(NULL AS VARCHAR(254))'

	// - 19.a, 19.b, 19.c. The catalogs, schemas or table types.
	if cat.value == sql_all_catalogs && sch.value == '' && tbl.value == '' {
		return exec_direct_text(mut stmt, 'SELECT DISTINCT TABLE_CAT, ${null} AS TABLE_SCHEM, ${null} AS TABLE_NAME, ${null254} AS TABLE_TYPE, ${null254} AS REMARKS FROM ${tables_query} ORDER BY TABLE_CAT')
	}
	if sch.value == sql_all_schemas && cat.value == '' && tbl.value == '' {
		return exec_direct_text(mut stmt, 'SELECT DISTINCT ${null} AS TABLE_CAT, TABLE_SCHEM, ${null} AS TABLE_NAME, ${null254} AS TABLE_TYPE, ${null254} AS REMARKS FROM ${tables_query} ORDER BY TABLE_SCHEM')
	}
	if typ.value == sql_all_table_types && cat.value == '' && sch.value == '' && tbl.value == '' {
		return exec_direct_text(mut stmt, 'SELECT DISTINCT ${null} AS TABLE_CAT, ${null} AS TABLE_SCHEM, ${null} AS TABLE_NAME, TABLE_TYPE, ${null254} AS REMARKS FROM ${tables_query} ORDER BY TABLE_TYPE')
	}

	// - 16, 17, 18. The predicate. TableType is a comma-separated list of
	// types, each of which may be quoted.
	mut pred := name_predicate(stmt, 'TABLE_CAT', cat, false) +
		name_predicate(stmt, 'TABLE_SCHEM', sch, true) +
		name_predicate(stmt, 'TABLE_NAME', tbl, true)
	if typ.value != '' {
		types := typ.value.split(',').map('TABLE_TYPE = ${sql_string(it.trim(' ').trim("'"))}')
		pred += '(${types.join(' OR ')}) AND '
	}

	// - 19.d, 20. ExecDirect is implicitly invoked.
	return exec_direct_text(mut stmt, 'SELECT * FROM ${tables_query} WHERE ${pred}1 = 1 ORDER BY TABLE_TYPE, TABLE_CAT, TABLE_SCHEM, TABLE_NAME')
}
