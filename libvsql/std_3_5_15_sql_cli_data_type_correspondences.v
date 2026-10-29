module main

import vsql

// ISO/IEC 9075-3:2003(E), 5.15, SQL/CLI data type correspondences
//
// The codes for SQL data types (Table 6 and Table 40) and application data
// types (Table 7), and the C type for each (Table 45).

// SQLInteger is SQLINTEGER in libvsql.h, the C type for an SQL INTEGER. Table 45
// says it's a C long, but that's 64 bits on macOS and Linux and 32 bits on
// Windows, so libvsql.h makes it 32 bits everywhere.
type SQLInteger = i32

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

// cast_value is CAST ( SV AS TDT ) for a number type. A datetime or BOOLEAN
// can't be cast to a number: dynamic SQL error — restricted data type
// attribute violation.
fn cast_value(stmt &Stmt, value vsql.Value, column vsql.Column, typ vsql.SQLType) !vsql.Value {
	if column.typ.typ in [.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
		.is_timestamp_without_time_zone, .is_timestamp_with_time_zone, .is_boolean] {
		return cli_error('07006', 'restricted data type attribute violation')
	}
	mut conn := dbcs[stmt.dbc] or { return cli_error('08003', 'connection does not exist') }.conn or {
		return cli_error('08003', 'connection does not exist')
	}

	return conn.store_assignment(value, vsql.Type{ typ: typ })!
}

// assign_number sets the host variable (of the C type for typ) at target to a
// number.
fn assign_number(value vsql.Value, typ vsql.SQLType, target voidptr) {
	unsafe {
		match typ {
			.is_smallint { *&i16(target) = i16(value.int_value()) }
			.is_integer { *&SQLInteger(target) = SQLInteger(value.int_value()) }
			.is_bigint { *&i64(target) = value.int_value() }
			.is_real { *&f32(target) = f32(value.f64_value()) }
			else { *&f64(target) = value.f64_value() }
		}
	}
}

// c_type_size is the size in octets of the C type for typ (from c_type), which
// is the size of each element of an array of them.
fn c_type_size(typ vsql.SQLType) int {
	return match typ {
		.is_smallint { 2 }
		.is_integer { int(sizeof(SQLInteger)) }
		.is_real { 4 }
		else { 8 }
	}
}
