module main

// The catalog routines (Tables, Columns, etc.) return a result set from the
// INFORMATION_SCHEMA, by implicitly invoking ExecDirect with a query that the
// standard defines for each of them (see 4.1, "Introduction to SQL/CLI").
//
// Each name argument is a pattern for LIKE (with the escape character "\"),
// unless the METADATA ID attribute of the statement is TRUE: then it's an
// identifier, which is case insensitive unless it's quoted.
//
// There are no privileges, so feature C041 isn't supported and every row of
// the INFORMATION_SCHEMA is described (for example ISO/IEC 9075-3:2003(E),
// 6.63, Tables, General Rules, 6.b.ii). The length of each argument is read
// before the null pointers are checked (for example General Rules, 10 and 12),
// which is #759.

// The search pattern escape (see GetInfo).
const search_pattern_escape = '\\'

// The special values from Table 42, "Special parameter values".
const sql_all_catalogs = '%'
const sql_all_schemas = '%'
const sql_all_table_types = '%'

// CatalogArg is a name argument of a catalog routine. is_null is true if it was
// a null pointer.
struct CatalogArg {
	value   string
	is_null bool
}

// catalog_arg reads a name argument of NameLength octets (or SQL_NTS). A null
// pointer is a zero-length string.
fn catalog_arg(name &char, name_length i16) !CatalogArg {
	if name == unsafe { nil } {
		return CatalogArg{
			is_null: true
		}
	}
	if name_length < 0 && name_length != sql_nts {
		return cli_error('HY090', 'invalid string length or buffer length')
	}

	return CatalogArg{
		value: input_string(name, i64(name_length))!
	}
}

// check_metadata_id_args raises an exception condition if the METADATA ID
// attribute is TRUE and an argument is a null pointer: CLI-specific condition
// — invalid use of null pointer. vsql supports catalog names, so the catalog
// can't be a null pointer either.
fn check_metadata_id_args(stmt &Stmt, args []CatalogArg) ! {
	if stmt.metadata_id == sql_true && args.any(it.is_null) {
		return cli_error('HY009', 'invalid use of null pointer')
	}
}

// name_predicate is the condition (followed by "AND") on a column for a name
// argument, or a zero-length string if the argument is a zero-length string.
// is_pattern is false for an argument that's compared exactly (the catalog).
fn name_predicate(stmt &Stmt, column string, arg CatalogArg, is_pattern bool) string {
	if arg.value == '' {
		return ''
	}

	if stmt.metadata_id == sql_true {
		trimmed := arg.value.trim(' ')
		if trimmed.len > 1 && trimmed.starts_with('"') && trimmed.ends_with('"') {
			return '${column} = ${sql_string(trimmed[1..trimmed.len - 1])} AND '
		}
		return 'UPPER(${column}) = UPPER(${sql_string(arg.value)}) AND '
	}

	if is_pattern {
		return '${column} LIKE ${sql_string(arg.value)} ESCAPE ${sql_string(search_pattern_escape)} AND '
	}

	return '${column} = ${sql_string(arg.value)} AND '
}

// sql_string is a <character string literal>.
fn sql_string(s string) string {
	return "'" + s.replace("'", "''") + "'"
}
