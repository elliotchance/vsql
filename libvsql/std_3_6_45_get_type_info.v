module main

// ISO/IEC 9075-3:2003(E), 6.45, GetTypeInfo
//
// Get information about one or all of the predefined data types supported by
// the implementation.
//
// There's a row for each data type that vsql supports (FLOAT is a DOUBLE
// PRECISION, but it has its own row because it has its own code).

// Codes from Table 26, "Miscellaneous codes used in CLI".
const sql_all_types = i16(0)

// The codes from Table 37, "Codes used for concise data types", that vsql
// doesn't support.
const unsupported_concise_types = [i16(17), 19, 20, 30, 40, 50, 55, 101, 102, 103, 104, 105, 106,
	107, 108, 109, 110, 111, 112, 113]

// TypeInfo is a row of TYPE_INFO. A zero (or zero-length string) is the null
// value, except for the codes.
struct TypeInfo {
	name             string
	code             i16
	column_size      int
	literal_prefix   string
	literal_suffix   string
	create_params    string
	searchable       int = 2
	unsigned         int = -1
	fixed_prec_scale int
	minimum_scale    int = -1
	maximum_scale    int = -1
	sql_data_type    i16
	datetime_sub     int
	num_prec_radix   int
}

const type_info = [
	TypeInfo{
		name:           'CHARACTER'
		code:           sql_char
		column_size:    10485760
		literal_prefix: "'"
		literal_suffix: "'"
		create_params:  'LENGTH'
		searchable:     3
		sql_data_type:  sql_char
	},
	TypeInfo{
		name:           'NUMERIC'
		code:           sql_numeric
		column_size:    1000
		create_params:  'PRECISION,SCALE'
		unsigned:       0
		minimum_scale:  0
		maximum_scale:  1000
		sql_data_type:  sql_numeric
		num_prec_radix: 10
	},
	TypeInfo{
		name:           'DECIMAL'
		code:           sql_decimal
		column_size:    1000
		create_params:  'PRECISION,SCALE'
		unsigned:       0
		minimum_scale:  0
		maximum_scale:  1000
		sql_data_type:  sql_decimal
		num_prec_radix: 10
	},
	TypeInfo{
		name:             'INTEGER'
		code:             sql_integer
		column_size:      32
		unsigned:         0
		fixed_prec_scale: 1
		minimum_scale:    0
		maximum_scale:    0
		sql_data_type:    sql_integer
		num_prec_radix:   2
	},
	TypeInfo{
		name:             'SMALLINT'
		code:             sql_smallint
		column_size:      16
		unsigned:         0
		fixed_prec_scale: 1
		minimum_scale:    0
		maximum_scale:    0
		sql_data_type:    sql_smallint
		num_prec_radix:   2
	},
	TypeInfo{
		name:           'FLOAT'
		code:           sql_float
		column_size:    53
		create_params:  'PRECISION'
		unsigned:       0
		sql_data_type:  sql_float
		num_prec_radix: 2
	},
	TypeInfo{
		name:           'REAL'
		code:           sql_real
		column_size:    24
		unsigned:       0
		sql_data_type:  sql_real
		num_prec_radix: 2
	},
	TypeInfo{
		name:           'DOUBLE PRECISION'
		code:           sql_double
		column_size:    53
		unsigned:       0
		sql_data_type:  sql_double
		num_prec_radix: 2
	},
	TypeInfo{
		name:           'CHARACTER VARYING'
		code:           sql_varchar
		column_size:    10485760
		literal_prefix: "'"
		literal_suffix: "'"
		create_params:  'LENGTH'
		searchable:     3
		sql_data_type:  sql_varchar
	},
	TypeInfo{
		name:          'BOOLEAN'
		code:          sql_boolean
		sql_data_type: sql_boolean
	},
	TypeInfo{
		name:             'BIGINT'
		code:             sql_bigint
		column_size:      64
		unsigned:         0
		fixed_prec_scale: 1
		minimum_scale:    0
		maximum_scale:    0
		sql_data_type:    sql_bigint
		num_prec_radix:   2
	},
	TypeInfo{
		name:           'DATE'
		code:           sql_type_date
		column_size:    10
		literal_prefix: "DATE '"
		literal_suffix: "'"
		sql_data_type:  sql_datetime
		datetime_sub:   sql_code_date
	},
	TypeInfo{
		name:           'TIME'
		code:           sql_type_time
		column_size:    15
		literal_prefix: "TIME '"
		literal_suffix: "'"
		create_params:  'PRECISION'
		minimum_scale:  0
		maximum_scale:  6
		sql_data_type:  sql_datetime
		datetime_sub:   sql_code_time
	},
	TypeInfo{
		name:           'TIMESTAMP'
		code:           sql_type_timestamp
		column_size:    26
		literal_prefix: "TIMESTAMP '"
		literal_suffix: "'"
		create_params:  'PRECISION'
		minimum_scale:  0
		maximum_scale:  6
		sql_data_type:  sql_datetime
		datetime_sub:   sql_code_timestamp
	},
	TypeInfo{
		name:           'TIME WITH TIME ZONE'
		code:           sql_type_time_with_timezone
		column_size:    21
		literal_prefix: "TIME '"
		literal_suffix: "'"
		create_params:  'PRECISION'
		minimum_scale:  0
		maximum_scale:  6
		sql_data_type:  sql_datetime
		datetime_sub:   sql_code_time_zone
	},
	TypeInfo{
		name:           'TIMESTAMP WITH TIME ZONE'
		code:           sql_type_timestamp_with_timezone
		column_size:    32
		literal_prefix: "TIMESTAMP '"
		literal_suffix: "'"
		create_params:  'PRECISION'
		minimum_scale:  0
		maximum_scale:  6
		sql_data_type:  sql_datetime
		datetime_sub:   sql_code_timestamp_zone
	},
]

@[export: 'SQLGetTypeInfo']
fn sql_get_type_info(statement_handle SQLInteger, data_type i16) i16 {
	entry := enter(sql_handle_stmt, i64(statement_handle))
	defer {
		entry.leave()
	}
	mut stmt := stmts[i64(statement_handle)] or { return sql_invalid_handle }
	stmt.diag.clear()
	stmt.invoke(false) or { return stmt.diag.error(err) }

	return get_type_info(mut stmt, data_type) or { stmt.diag.error(err) }
}

fn get_type_info(mut stmt Stmt, data_type i16) !i16 {
	// - 2. If an open cursor is associated with S, then an exception condition
	// is raised: invalid cursor state.
	if stmt.cursor != none {
		return cli_error('24000', 'invalid cursor state')
	}

	// - 4. D must be ALL TYPES or one of the codes in Table 37, "Codes used for
	// concise data types", otherwise an exception condition is raised:
	// CLI-specific condition — invalid data type.
	if data_type != sql_all_types && data_type !in type_info.map(it.code)
		&& data_type !in unsupported_concise_types {
		return cli_error('HY004', 'invalid data type')
	}

	// - 9, 10. ExecDirect is implicitly invoked.
	where := if data_type == sql_all_types { '' } else { 'WHERE DATA_TYPE = ${data_type}' }

	return exec_direct_text(mut stmt, 'SELECT * FROM ${type_info_table()} ${where} ORDER BY DATA_TYPE')
}

// type_info_table is TYPE_INFO (General Rules 7 and 8).
fn type_info_table() string {
	str := fn (s string) string {
		return if s == '' {
			'CAST(NULL AS VARCHAR(128))'
		} else {
			'CAST(${sql_string(s)} AS VARCHAR(128))'
		}
	}
	smallint := fn (n int) string {
		return if n < 0 { 'CAST(NULL AS SMALLINT)' } else { 'CAST(${n} AS SMALLINT)' }
	}
	integer := fn (n int) string {
		return if n < 0 { 'CAST(NULL AS INTEGER)' } else { 'CAST(${n} AS INTEGER)' }
	}

	mut rows := []string{}
	for t in type_info {
		rows << 'ROW(${str(t.name)}, ${smallint(t.code)}, ${integer(if t.column_size == 0 {
			-1
		} else {
			t.column_size
		})}, ${str(t.literal_prefix)}, ${str(t.literal_suffix)}, ${str(t.create_params)}, ${smallint(sql_nullable)}, ${smallint(if t.literal_prefix == "'" {
			1
		} else {
			0
		})}, ${smallint(t.searchable)}, ${smallint(t.unsigned)}, ${smallint(t.fixed_prec_scale)}, ${smallint(0)}, ${str('')}, ${integer(t.minimum_scale)}, ${integer(t.maximum_scale)}, ${smallint(t.sql_data_type)}, ${smallint(if t.datetime_sub == 0 {
			-1
		} else {
			t.datetime_sub
		})}, ${integer(if t.num_prec_radix == 0 {
			-1
		} else {
			t.num_prec_radix
		})}, ${smallint(-1)})'
	}

	return '(VALUES ${rows.join(', ')}) AS TYPE_INFO (TYPE_NAME, DATA_TYPE, COLUMN_SIZE, LITERAL_PREFIX, LITERAL_SUFFIX, CREATE_PARAMS, NULLABLE, CASE_SENSITIVE, SEARCHABLE, UNSIGNED_ATTRIBUTE, FIXED_PREC_SCALE, AUTO_UNIQUE_VALUE, LOCAL_TYPE_NAME, MINIMUM_SCALE, MAXIMUM_SCALE, SQL_DATA_TYPE, SQL_DATETIME_SUB, NUM_PREC_RADIX, INTERVAL_PRECISION)'
}
