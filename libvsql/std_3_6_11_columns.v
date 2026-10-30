module main

// ISO/IEC 9075-3:2003(E), 6.11, Columns
//
// Based on the specified selection criteria, return a result set that contains
// information about columns of tables stored in the information schemas of the
// connected data source.
//
// There are no interval, LOB or reference types (General Rules, 7.e.i, 7.g.v,
// 7.g.vi, 7.n.ii and 7.r.ii). TYPE_NAME is the DATA_TYPE of the COLUMNS view,
// the COLUMN_SIZE of a number is its decimal digits, and REMARKS is the null
// value (General Rules, 7.f, 7.g.iii and 7.l), which are
// implementation-defined.

@[export: 'SQLColumns']
fn sql_columns(statement_handle SQLInteger, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, column_name &char, name_length4 i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return columns(mut stmt, catalog_name, name_length1, schema_name, name_length2, table_name,
		name_length3, column_name, name_length4) or { stmt.diag.error(err) }
}

fn columns(mut stmt Stmt, catalog_name &char, name_length1 i16, schema_name &char, name_length2 i16, table_name &char, name_length3 i16, column_name &char, name_length4 i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 8 to 15. The arguments.
	cat := catalog_arg(catalog_name, name_length1)!
	sch := catalog_arg(schema_name, name_length2)!
	tbl := catalog_arg(table_name, name_length3)!
	col := catalog_arg(column_name, name_length4)!
	check_metadata_id_args(stmt, [cat, sch, tbl, col])!

	// - 16, 17. The predicate.
	pred := name_predicate(stmt, 'TABLE_CAT', cat, false) +
		name_predicate(stmt, 'TABLE_SCHEM', sch, true) +
		name_predicate(stmt, 'TABLE_NAME', tbl, true) +
		name_predicate(stmt, 'COLUMN_NAME', col, true)

	// - 18, 19. ExecDirect is implicitly invoked.
	return exec_direct_text(mut stmt, 'SELECT * FROM ${columns_query()} AS COLUMNS_QUERY WHERE ${pred}1 = 1 ORDER BY TABLE_CAT, TABLE_SCHEM, TABLE_NAME, ORDINAL_POSITION')
}

// columns_query is COLUMNS_QUERY (General Rules 5 to 7), without its alias.
fn columns_query() string {
	// - 7.e. DATA_TYPE is the concise code for the data type.
	data_type := 'CASE DATA_TYPE
		WHEN \'CHARACTER\' THEN ${sql_char}
		WHEN \'CHARACTER VARYING\' THEN ${sql_varchar}
		WHEN \'NUMERIC\' THEN ${sql_numeric}
		WHEN \'DECIMAL\' THEN ${sql_decimal}
		WHEN \'INTEGER\' THEN ${sql_integer}
		WHEN \'SMALLINT\' THEN ${sql_smallint}
		WHEN \'BIGINT\' THEN ${sql_bigint}
		WHEN \'REAL\' THEN ${sql_real}
		WHEN \'DOUBLE PRECISION\' THEN ${sql_double}
		WHEN \'BOOLEAN\' THEN ${sql_boolean}
		WHEN \'DATE\' THEN ${sql_type_date}
		WHEN \'TIME\' THEN ${sql_type_time}
		WHEN \'TIMESTAMP\' THEN ${sql_type_timestamp}
		WHEN \'TIME WITH TIME ZONE\' THEN ${sql_type_time_with_timezone}
		WHEN \'TIMESTAMP WITH TIME ZONE\' THEN ${sql_type_timestamp_with_timezone}
	END'

	// - 7.g. COLUMN_SIZE is the length of a string, the precision of a
	// DECIMAL or NUMERIC (and the decimal digits of other numbers), or the
	// length in positions of a datetime (including the fractional seconds).
	fraction := 'CASE WHEN DATETIME_PRECISION > 0 THEN DATETIME_PRECISION + 1 ELSE 0 END'
	column_size := 'CASE DATA_TYPE
		WHEN \'CHARACTER\' THEN CHARACTER_MAXIMUM_LENGTH
		WHEN \'CHARACTER VARYING\' THEN CHARACTER_MAXIMUM_LENGTH
		WHEN \'NUMERIC\' THEN NUMERIC_PRECISION
		WHEN \'DECIMAL\' THEN NUMERIC_PRECISION
		WHEN \'SMALLINT\' THEN 5
		WHEN \'INTEGER\' THEN 10
		WHEN \'BIGINT\' THEN 19
		WHEN \'REAL\' THEN 7
		WHEN \'DOUBLE PRECISION\' THEN 15
		WHEN \'BOOLEAN\' THEN 5
		WHEN \'DATE\' THEN 10
		WHEN \'TIME\' THEN 8 + ${fraction}
		WHEN \'TIME WITH TIME ZONE\' THEN 14 + ${fraction}
		WHEN \'TIMESTAMP\' THEN 19 + ${fraction}
		WHEN \'TIMESTAMP WITH TIME ZONE\' THEN 25 + ${fraction}
	END'

	// - 7.h. BUFFER_LENGTH is the number of octets for a column with a C type
	// (which is what SQL_DEFAULT retrieves).
	buffer_length := 'CASE DATA_TYPE
		WHEN \'CHARACTER\' THEN CHARACTER_OCTET_LENGTH
		WHEN \'SMALLINT\' THEN 2
		WHEN \'INTEGER\' THEN ${sizeof(SQLInteger)}
		WHEN \'BIGINT\' THEN 8
		WHEN \'REAL\' THEN 4
		WHEN \'DOUBLE PRECISION\' THEN 8
	END'

	// - 7.i. DECIMAL_DIGITS is the fractional seconds of a datetime, or the
	// scale of an exact number.
	decimal_digits := "CASE
		WHEN DATA_TYPE IN ('DATE', 'TIME', 'TIMESTAMP', 'TIME WITH TIME ZONE', 'TIMESTAMP WITH TIME ZONE') THEN DATETIME_PRECISION
		WHEN DATA_TYPE IN ('NUMERIC', 'DECIMAL', 'SMALLINT', 'INTEGER', 'BIGINT') THEN NUMERIC_SCALE
	END"

	// - 7.n, 7.r. A datetime is DATETIME, with its DATETIME_INTERVAL_CODE.
	datetime_sub := 'CASE DATA_TYPE
		WHEN \'DATE\' THEN ${sql_code_date}
		WHEN \'TIME\' THEN ${sql_code_time}
		WHEN \'TIMESTAMP\' THEN ${sql_code_timestamp}
		WHEN \'TIME WITH TIME ZONE\' THEN ${sql_code_time_zone}
		WHEN \'TIMESTAMP WITH TIME ZONE\' THEN ${sql_code_timestamp_zone}
	END'

	return '(SELECT
		CAST(TABLE_CATALOG AS VARCHAR(128)) AS TABLE_CAT,
		CAST(TABLE_SCHEMA AS VARCHAR(128)) AS TABLE_SCHEM,
		CAST(TABLE_NAME AS VARCHAR(128)) AS TABLE_NAME,
		CAST(COLUMN_NAME AS VARCHAR(128)) AS COLUMN_NAME,
		CAST(${data_type} AS SMALLINT) AS DATA_TYPE,
		CAST(DATA_TYPE AS VARCHAR(128)) AS TYPE_NAME,
		CAST(${column_size} AS INTEGER) AS COLUMN_SIZE,
		CAST(${buffer_length} AS INTEGER) AS BUFFER_LENGTH,
		CAST(${decimal_digits} AS SMALLINT) AS DECIMAL_DIGITS,
		CAST(NUMERIC_PRECISION_RADIX AS SMALLINT) AS NUM_PREC_RADIX,
		CAST(CASE IS_NULLABLE WHEN \'NO\' THEN ${sql_no_nulls} ELSE ${sql_nullable} END AS SMALLINT) AS NULLABLE,
		CAST(NULL AS VARCHAR(254)) AS REMARKS,
		CAST(COLUMN_DEFAULT AS VARCHAR(254)) AS COLUMN_DEF,
		CAST(CASE WHEN ${datetime_sub} IS NULL THEN ${data_type} ELSE ${sql_datetime} END AS SMALLINT) AS SQL_DATA_TYPE,
		CAST(${datetime_sub} AS INTEGER) AS SQL_DATETIME_SUB,
		CAST(CHARACTER_OCTET_LENGTH AS INTEGER) AS CHAR_OCTET_LENGTH,
		CAST(ORDINAL_POSITION AS INTEGER) AS ORDINAL_POSITION,
		CAST(IS_NULLABLE AS VARCHAR(254)) AS IS_NULLABLE,
		CAST(CHARACTER_SET_CATALOG AS VARCHAR(128)) AS CHAR_SET_CAT,
		CAST(CHARACTER_SET_SCHEMA AS VARCHAR(128)) AS CHAR_SET_SCHEM,
		CAST(CHARACTER_SET_NAME AS VARCHAR(128)) AS CHAR_SET_NAME,
		CAST(COLLATION_CATALOG AS VARCHAR(128)) AS COLLATION_CAT,
		CAST(COLLATION_SCHEMA AS VARCHAR(128)) AS COLLATION_SCHEM,
		CAST(COLLATION_NAME AS VARCHAR(128)) AS COLLATION_NAME,
		CAST(UDT_CATALOG AS VARCHAR(128)) AS UDT_CAT,
		CAST(UDT_SCHEMA AS VARCHAR(128)) AS UDT_SCHEM,
		CAST(UDT_NAME AS VARCHAR(128)) AS UDT_NAME,
		CAST(DOMAIN_CATALOG AS VARCHAR(128)) AS DOMAIN_CAT,
		CAST(DOMAIN_SCHEMA AS VARCHAR(128)) AS DOMAIN_SCHEM,
		CAST(DOMAIN_NAME AS VARCHAR(128)) AS DOMAIN_NAME,
		CAST(SCOPE_CATALOG AS VARCHAR(128)) AS SCOPE_CAT,
		CAST(SCOPE_SCHEMA AS VARCHAR(128)) AS SCOPE_SCHEM,
		CAST(SCOPE_NAME AS VARCHAR(128)) AS SCOPE_NAME,
		CAST(MAXIMUM_CARDINALITY AS INTEGER) AS MAX_CARDINALITY,
		CAST(DTD_IDENTIFIER AS VARCHAR(128)) AS DTD_IDENTIFIER,
		CAST(IS_SELF_REFERENCING AS VARCHAR(128)) AS IS_SELF_REF
	FROM INFORMATION_SCHEMA.COLUMNS)'
}
