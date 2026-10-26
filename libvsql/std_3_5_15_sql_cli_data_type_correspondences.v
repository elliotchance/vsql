module main

import vsql

// ISO/IEC 9075-3:2003(E), 5.15, SQL/CLI data type correspondences
//
// The codes for SQL data types (Table 6 and Table 40) and application data
// types (Table 7), and the C type for each (Table 45).

const sql_char = i16(1)
const sql_numeric = i16(2)
const sql_decimal = i16(3)
const sql_integer = i16(4)
const sql_smallint = i16(5)
const sql_float = i16(6)
const sql_real = i16(7)
const sql_double = i16(8)
const sql_datetime = i16(9)
const sql_varchar = i16(12)
const sql_boolean = i16(16)
const sql_bigint = i16(25)
const sql_type_date = i16(91)
const sql_type_time = i16(92)
const sql_type_timestamp = i16(93)
const sql_type_time_with_timezone = i16(94)
const sql_type_timestamp_with_timezone = i16(95)

// Codes from Table 26, "Miscellaneous codes used in CLI".
const sql_default = i16(99)
const sql_ard_type = i16(-99)
const sql_null_data = -1
const sql_no_nulls = i16(0)
const sql_nullable = i16(1)

// data_type_code is the code for the data type of a column, with the concise
// code for datetime types.
fn data_type_code(typ vsql.Type) i16 {
	return match typ.typ {
		.is_bigint { sql_bigint }
		.is_boolean { sql_boolean }
		.is_character { sql_char }
		.is_double_precision { sql_double }
		.is_integer { sql_integer }
		.is_real { sql_real }
		.is_smallint { sql_smallint }
		.is_varchar { sql_varchar }
		.is_decimal { sql_decimal }
		.is_numeric { sql_numeric }
		.is_date { sql_type_date }
		.is_time_without_time_zone { sql_type_time }
		.is_time_with_time_zone { sql_type_time_with_timezone }
		.is_timestamp_without_time_zone { sql_type_timestamp }
		.is_timestamp_with_time_zone { sql_type_timestamp_with_timezone }
	}
}

// c_type returns the SQL type for an application data type, or none if the
// type has no C data type in Table 45.
fn c_type(code i16) ?vsql.SQLType {
	return match code {
		sql_char { vsql.SQLType.is_varchar }
		sql_smallint { vsql.SQLType.is_smallint }
		sql_integer { vsql.SQLType.is_integer }
		sql_bigint { vsql.SQLType.is_bigint }
		sql_real { vsql.SQLType.is_real }
		sql_double { vsql.SQLType.is_double_precision }
		else { none }
	}
}
