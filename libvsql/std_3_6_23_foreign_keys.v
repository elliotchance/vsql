module main

// ISO/IEC 9075-3:2003(E), 6.23, ForeignKeys
//
// Return a result set that contains information about foreign keys either in or
// referencing a single specified table stored in the Information Schema of the
// connected data source.
//
// With a PKTableName, the result set is the foreign keys that reference the
// primary key of the table. With an FKTableName, it's the foreign keys of the
// table (that reference a primary or unique key). With both, it's the foreign
// keys of the FKTableName that reference the primary or unique keys of the
// PKTableName, and with neither, it's every foreign key.

// Codes from Table 26, "Miscellaneous codes used in CLI".
const sql_cascade = i16(0)
const sql_restrict = i16(1)
const sql_set_null = i16(2)
const sql_no_action = i16(3)
const sql_set_default = i16(4)
const sql_initially_deferred = i16(5)
const sql_initially_immediate = i16(6)
const sql_not_deferrable = i16(7)

@[export: 'SQLForeignKeys']
fn sql_foreign_keys(statement_handle SQLInteger, pk_catalog_name &char, name_length1 i16, pk_schema_name &char, name_length2 i16, pk_table_name &char, name_length3 i16, fk_catalog_name &char, name_length4 i16, fk_schema_name &char, name_length5 i16, fk_table_name &char, name_length6 i16) i16 {
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.check_deferred() or { return stmt.diag.error(err) }

	return foreign_keys(mut stmt, [
		catalog_arg(pk_catalog_name, name_length1) or { return stmt.diag.error(err) },
		catalog_arg(pk_schema_name, name_length2) or { return stmt.diag.error(err) },
		catalog_arg(pk_table_name, name_length3) or { return stmt.diag.error(err) },
		catalog_arg(fk_catalog_name, name_length4) or { return stmt.diag.error(err) },
		catalog_arg(fk_schema_name, name_length5) or { return stmt.diag.error(err) },
		catalog_arg(fk_table_name, name_length6) or { return stmt.diag.error(err) },
	]) or { stmt.diag.error(err) }
}

fn foreign_keys(mut stmt Stmt, args []CatalogArg) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	pk_given := args[2].value != ''
	fk_given := args[5].value != ''

	// - 7.a.xii. With METADATA ID, the names of the given table can't be null
	// pointers.
	if pk_given {
		check_metadata_id_args(stmt, args[..3])!
	}
	if fk_given {
		check_metadata_id_args(stmt, args[3..])!
	}

	// - 7.b. Only the primary key of the PKTableName.
	mut pred := if pk_given && !fk_given { "UNIQUE_OR_PRIMARY = 'PRIMARY' AND " } else { '' }
	if pk_given {
		pred += name_predicate(stmt, 'UK_TABLE_CAT', args[0], false) +
			name_predicate(stmt, 'UK_TABLE_SCHEM', args[1], false) +
			name_predicate(stmt, 'UK_TABLE_NAME', args[2], false)
	}
	if fk_given {
		pred += name_predicate(stmt, 'FK_TABLE_CAT', args[3], false) +
			name_predicate(stmt, 'FK_TABLE_SCHEM', args[4], false) +
			name_predicate(stmt, 'FK_TABLE_NAME', args[5], false)
	}

	// - 7.a.xix, 7.a.xx. ExecDirect is implicitly invoked. The rows of each
	// foreign key are together.
	return exec_direct_text(mut stmt, 'SELECT * FROM ${foreign_keys_query()} WHERE ${pred}1 = 1 ORDER BY FK_TABLE_CAT, FK_TABLE_SCHEM, FK_TABLE_NAME, FK_NAME, ORDINAL_POSITION')
}

// foreign_keys_query is FOREIGN_KEYS_QUERY (General Rule 7.a): each column of
// each foreign key (from KEY_COLUMN_USAGE), and the column of the unique key
// that it references.
fn foreign_keys_query() string {
	rule := fn (column string) string {
		return 'CAST(CASE ${column}
			WHEN \'CASCADE\' THEN ${sql_cascade}
			WHEN \'RESTRICT\' THEN ${sql_restrict}
			WHEN \'SET NULL\' THEN ${sql_set_null}
			WHEN \'NO ACTION\' THEN ${sql_no_action}
			WHEN \'SET DEFAULT\' THEN ${sql_set_default}
		END AS SMALLINT)'
	}

	return '(SELECT
		CAST(U.TABLE_CATALOG AS VARCHAR(128)) AS UK_TABLE_CAT,
		CAST(U.TABLE_SCHEMA AS VARCHAR(128)) AS UK_TABLE_SCHEM,
		CAST(U.TABLE_NAME AS VARCHAR(128)) AS UK_TABLE_NAME,
		CAST(U.COLUMN_NAME AS VARCHAR(128)) AS UK_COLUMN_NAME,
		CAST(F.TABLE_CATALOG AS VARCHAR(128)) AS FK_TABLE_CAT,
		CAST(F.TABLE_SCHEMA AS VARCHAR(128)) AS FK_TABLE_SCHEM,
		CAST(F.TABLE_NAME AS VARCHAR(128)) AS FK_TABLE_NAME,
		CAST(F.COLUMN_NAME AS VARCHAR(128)) AS FK_COLUMN_NAME,
		CAST(F.ORDINAL_POSITION AS SMALLINT) AS ORDINAL_POSITION,
		${rule('R.UPDATE_RULE')} AS UPDATE_RULE,
		${rule('R.DELETE_RULE')} AS DELETE_RULE,
		CAST(R.CONSTRAINT_NAME AS VARCHAR(128)) AS FK_NAME,
		CAST(R.UNIQUE_CONSTRAINT_NAME AS VARCHAR(128)) AS UK_NAME,
		CAST(${sql_not_deferrable} AS SMALLINT) AS DEFERABILITY,
		CAST(CASE T.CONSTRAINT_TYPE WHEN \'PRIMARY KEY\' THEN \'PRIMARY\' ELSE \'UNIQUE\' END AS CHARACTER(7)) AS UNIQUE_OR_PRIMARY
	FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS AS R
	JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS F
		ON F.CONSTRAINT_CATALOG = R.CONSTRAINT_CATALOG
		AND F.CONSTRAINT_SCHEMA = R.CONSTRAINT_SCHEMA
		AND F.CONSTRAINT_NAME = R.CONSTRAINT_NAME
	JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS U
		ON U.CONSTRAINT_CATALOG = R.UNIQUE_CONSTRAINT_CATALOG
		AND U.CONSTRAINT_SCHEMA = R.UNIQUE_CONSTRAINT_SCHEMA
		AND U.CONSTRAINT_NAME = R.UNIQUE_CONSTRAINT_NAME
		AND U.ORDINAL_POSITION = F.POSITION_IN_UNIQUE_CONSTRAINT
	JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS T
		ON T.CONSTRAINT_CATALOG = R.UNIQUE_CONSTRAINT_CATALOG
		AND T.CONSTRAINT_SCHEMA = R.UNIQUE_CONSTRAINT_SCHEMA
		AND T.CONSTRAINT_NAME = R.UNIQUE_CONSTRAINT_NAME) AS FOREIGN_KEYS_QUERY'
}
