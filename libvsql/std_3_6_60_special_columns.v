module main

// ISO/IEC 9075-3:2003(E), 6.60, SpecialColumns
//
// Return a result set that contains a list of columns the combined values of
// which can uniquely identify any row within a single specified table described
// by the Information Schemas of the connected data source.
//
// The columns that best identify a row are the PRIMARY KEY (a table without
// one has none). The values are valid for the SQL-session (unless they're
// updated), and they aren't pseudo-columns (General Rules, 10.a.iii and 10.h).
// The columns of a PRIMARY KEY are never null, so General Rules 22.a never
// applies. There are no interval or reference types (General Rules, 10.c.i,
// 10.e.v and 10.e.vi).

// Codes from Table 43, "Column types and scopes used with SpecialColumns".
const sql_best_rowid = i16(1)
const sql_scope_currow = i16(0)
const sql_scope_transaction = i16(1)
const sql_scope_session = i16(2)
const sql_pc_unknown = i16(0)
const sql_pc_not_pseudo = i16(1)
const sql_pc_pseudo = i16(2)

@[export: 'SQLSpecialColumns']
fn sql_special_columns(statement_handle SQLInteger, identifier_type i16, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, scope i16, nullable i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return special_columns(mut stmt, identifier_type, catalog_name, name_length1, schema_name,
		name_length2, table_name, name_length3, scope, nullable) or { stmt.diag.error(err) }
}

fn special_columns(mut stmt Stmt, identifier_type i16, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, scope i16, nullable i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 7, 8, 9. The IdentifierType, Scope and Nullable must be codes from
	// Table 43.
	if identifier_type != sql_best_rowid {
		return cli_error('HY097', 'column type out of range')
	}
	if scope !in [sql_scope_currow, sql_scope_transaction, sql_scope_session] {
		return cli_error('HY098', 'scope out of range')
	}
	if nullable !in [sql_no_nulls, sql_nullable] {
		return cli_error('HY099', 'nullable type out of range')
	}

	// - 11 to 18. The arguments. The table must be given (it's not a pattern).
	cat := catalog_arg(catalog_name, name_length1)!
	sch := catalog_arg(schema_name, name_length2)!
	tbl := catalog_arg(table_name, name_length3)!
	check_metadata_id_args(stmt, [cat, sch])!
	if tbl.is_null {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	// - 19 to 23. ExecDirect is implicitly invoked. The columns of a PRIMARY
	// KEY are never null, so Nullable doesn't change the result. SCOPE is a
	// reserved word, so it's quoted.
	pred := name_predicate(stmt, 'TABLE_CAT', cat, false) +
		name_predicate(stmt, 'TABLE_SCHEM', sch, false) +
		name_predicate(stmt, 'TABLE_NAME', tbl, false)

	return exec_direct_text(mut stmt, 'SELECT "SCOPE", COLUMN_NAME, DATA_TYPE, TYPE_NAME, COLUMN_SIZE, BUFFER_LENGTH, DECIMAL_DIGITS, PSEUDO_COLUMN FROM ${special_columns_query()} WHERE ${pred}"SCOPE" >= ${scope} ORDER BY "SCOPE", KEY_POSITION')
}

// special_columns_query is SPECIAL_COLUMNS_QUERY (General Rules 5 to 10), with
// the table and the position of each column in the key.
fn special_columns_query() string {
	return '(SELECT
		CAST(${sql_scope_session} AS SMALLINT) AS "SCOPE",
		C.COLUMN_NAME,
		C.DATA_TYPE,
		C.TYPE_NAME,
		C.COLUMN_SIZE,
		C.BUFFER_LENGTH,
		C.DECIMAL_DIGITS,
		CAST(${sql_pc_not_pseudo} AS SMALLINT) AS PSEUDO_COLUMN,
		C.TABLE_CAT,
		C.TABLE_SCHEM,
		C.TABLE_NAME,
		K.ORDINAL_POSITION AS KEY_POSITION
	FROM ${columns_query()} AS C
	JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS K
		ON K.TABLE_CATALOG = C.TABLE_CAT
		AND K.TABLE_SCHEMA = C.TABLE_SCHEM
		AND K.TABLE_NAME = C.TABLE_NAME
		AND K.COLUMN_NAME = C.COLUMN_NAME
	JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS T
		ON T.CONSTRAINT_CATALOG = K.CONSTRAINT_CATALOG
		AND T.CONSTRAINT_SCHEMA = K.CONSTRAINT_SCHEMA
		AND T.CONSTRAINT_NAME = K.CONSTRAINT_NAME
	WHERE T.CONSTRAINT_TYPE = \'PRIMARY KEY\') AS SPECIAL_COLUMNS_QUERY'
}
