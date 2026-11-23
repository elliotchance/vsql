// type.v contains internal definitions and utilities for SQL data types.

module vsql

import math

// The concepts are described by:
//
// ISO/IEC 9075-1:2023, 4.6, SQL data types
// ISO/IEC 9075-1:2023, 4.6.1, General data type information
// ISO/IEC 9075-1:2023, 4.6.3, Predefined types

// Type is a fully-qualified SQL type, such as the type of a column or a value.
pub struct Type {
pub mut:
	// Base SQL type.
	typ SQLType
	// The size specified for the type.
	size int
	// The scale is only for numeric types.
	scale i16
	// Is NOT NULL?
	not_null bool
	// octets is true when the size of a character string type is in octets
	// (such as CHARACTER VARYING(10 OCTETS)) rather than characters.
	octets bool
}

// SQLType is the fundamental SQL type, without its size or precision.
pub enum SQLType {
	is_bigint                      // BIGINT
	is_boolean                     // BOOLEAN
	is_character                   // CHARACTER(n), CHAR(n), CHARACTER and CHAR
	is_double_precision            // DOUBLE PRECISION, FLOAT and FLOAT(n)
	is_integer                     // INTEGER and INT
	is_real                        // REAL
	is_smallint                    // SMALLINT
	is_varchar                     // CHARACTER VARYING, CHAR VARYING and VARCHAR
	is_date                        // DATE
	is_time_without_time_zone      // TIME, TIME WITHOUT TIME ZONE
	is_time_with_time_zone         // TIME WITH TIME ZONE
	is_timestamp_without_time_zone // TIMESTAMP, TIMESTAMP WITHOUT TIME ZONE
	is_timestamp_with_time_zone    // TIMESTAMP WITH TIME ZONE
	is_decimal                     // DECIMAL
	is_numeric                     // NUMERIC
	is_clob                        // CHARACTER LARGE OBJECT, CHAR LARGE OBJECT and CLOB
	is_binary                      // BINARY(n) and BINARY
	is_varbinary                   // BINARY VARYING(n) and VARBINARY(n)
	is_blob                        // BINARY LARGE OBJECT and BLOB
	is_decfloat                    // DECFLOAT(p) and DECFLOAT
	is_interval_year_month         // INTERVAL YEAR, MONTH or YEAR TO MONTH
	is_interval_day_time           // INTERVAL DAY, HOUR, MINUTE, SECOND or a range of them
}

// The SQL representation, such as ``TIME WITHOUT TIME ZONE``.
fn (t SQLType) str() string {
	return match t {
		.is_bigint { 'BIGINT' }
		.is_boolean { 'BOOLEAN' }
		.is_character { 'CHARACTER' }
		.is_double_precision { 'DOUBLE PRECISION' }
		.is_integer { 'INTEGER' }
		.is_real { 'REAL' }
		.is_smallint { 'SMALLINT' }
		.is_varchar { 'CHARACTER VARYING' }
		.is_date { 'DATE' }
		.is_time_without_time_zone { 'TIME WITHOUT TIME ZONE' }
		.is_time_with_time_zone { 'TIME WITH TIME ZONE' }
		.is_timestamp_without_time_zone { 'TIMESTAMP WITHOUT TIME ZONE' }
		.is_timestamp_with_time_zone { 'TIMESTAMP WITH TIME ZONE' }
		.is_numeric { 'NUMERIC' }
		.is_decimal { 'DECIMAL' }
		.is_clob { 'CHARACTER LARGE OBJECT' }
		.is_binary { 'BINARY' }
		.is_varbinary { 'BINARY VARYING' }
		.is_blob { 'BINARY LARGE OBJECT' }
		.is_decfloat { 'DECFLOAT' }
		.is_interval_year_month, .is_interval_day_time { 'INTERVAL' }
	}
}

fn (t SQLType) is_number() bool {
	return match t {
		.is_bigint, .is_double_precision, .is_integer, .is_real, .is_smallint, .is_decimal,
		.is_numeric {
			true
		}
		else {
			false
		}
	}
}

fn (t SQLType) is_string() bool {
	return match t {
		.is_character, .is_varchar, .is_clob { true }
		else { false }
	}
}

// is_binary_string is true for BINARY, BINARY VARYING and BINARY LARGE OBJECT.
fn (t SQLType) is_binary_string() bool {
	return t in [.is_binary, .is_varbinary, .is_blob]
}

// is_interval is true for a year-month or day-time interval.
fn (t SQLType) is_interval() bool {
	return t in [.is_interval_year_month, .is_interval_day_time]
}

fn (t SQLType) is_datetime() bool {
	return match t {
		.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
		.is_timestamp_without_time_zone, .is_timestamp_with_time_zone {
			true
		}
		else {
			false
		}
	}
}

// A greater supertype means a literal value is allowed to be cast up to it.
// However, you cannot cast between different categories. The same category and
// supertype does not mean that they are the same type - casting may still be
// required,
fn (t SQLType) supertype() (i16, i16) {
	return match t {
		// Booleans are on their own.
		.is_boolean {
			0, 0
		}
		// Character types are all equal but would be subject to limitations of the
		// allowed size.
		.is_character, .is_varchar, .is_clob {
			1, 0
		}
		// Exact numeric types.
		.is_smallint {
			2, 0
		}
		.is_integer {
			2, 1
		}
		.is_bigint {
			2, 2
		}
		.is_numeric {
			2, 3
		}
		.is_decimal {
			2, 4
		}
		// Approximate numeric types.
		.is_real {
			3, 0
		}
		.is_double_precision {
			3, 1
		}
		// Dates and times cannot be implicitly cast.
		.is_date, .is_time_without_time_zone, .is_time_with_time_zone,
		.is_timestamp_without_time_zone, .is_timestamp_with_time_zone {
			4, 0
		}
		// Binary strings, decimal floating-point numbers and the two classes of
		// intervals are each on their own, until the operators that combine them
		// with other types are supported.
		.is_binary, .is_varbinary, .is_blob {
			5, 0
		}
		.is_decfloat {
			6, 0
		}
		.is_interval_year_month {
			7, 0
		}
		.is_interval_day_time {
			8, 0
		}
	}
}

// exact_arithmetic_type is the type of the result of +, - or * with two exact
// numeric operands. The scale is max(S1, S2) for + and -, and S1 + S2 for *.
// The precision is implementation-defined, so it's large enough to hold any
// result, up to the maximum precision. It's 0 (the maximum) if either precision
// is unknown. The scale isn't limited, check_derived_scale rejects a scale that
// is more than the maximum when the expression is prepared.
//
// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, Syntax Rules, 1.c
fn exact_arithmetic_type(t1 Type, t2 Type, op string) Type {
	typ := if t1.typ == .is_decimal || t2.typ == .is_decimal {
		SQLType.is_decimal
	} else {
		SQLType.is_numeric
	}
	p1, s1 := t1.exact_precision(), t1.scale
	p2, s2 := t2.exact_precision(), t2.scale

	if op == '*' {
		size := if p1 == 0 || p2 == 0 { 0 } else { p1 + p2 }
		return Type{typ, math.min(size, max_numeric_precision), s1 + s2, false, false}
	}

	scale := if s1 > s2 { s1 } else { s2 }
	integer_digits := if p1 - s1 > p2 - s2 { p1 - s1 } else { p2 - s2 }
	size := if p1 == 0 || p2 == 0 { 0 } else { integer_digits + scale + 1 }

	return Type{typ, math.min(size, max_numeric_precision), scale, false, false}
}

// check_derived_scale returns t, or an error if it's a NUMERIC or DECIMAL that
// was derived from other types (such as the result of an arithmetic operator)
// with a scale more than the maximum scale. The maximum scale is the same as the
// maximum precision. The precision of a derived type is implementation-defined,
// so it's limited to the maximum precision instead, but the scale can't be
// reduced without changing the result.
//
// ISO/IEC 9075-2:2023, 6.1, <data type>, Syntax Rules, 27.b
fn check_derived_scale(t Type) !Type {
	if t.scale > max_numeric_precision {
		return sqlstate_42601('${t.typ} scale ${t.scale} is greater than the maximum of ${max_numeric_precision}')
	}

	return t
}

// exact_precision is the number of decimal digits that an exact numeric type
// can hold.
fn (t Type) exact_precision() int {
	return match t.typ {
		.is_smallint { 5 }
		.is_integer { 10 }
		.is_bigint { 19 }
		else { t.size }
	}
}

// numeric_precision is the precision of a NUMERIC or DECIMAL. One without a
// precision (a size of 0) has the maximum precision.
fn (t Type) numeric_precision() int {
	if t.size == 0 {
		return max_numeric_precision
	}

	return t.size
}

// implicit_cast_type is the type to implicitly cast v to when it needs to be
// the base type of t, such as for an operator or function argument. An exact
// numeric keeps its own precision and scale because a NUMERIC or DECIMAL without
// a size has a scale of 0, which would remove any fractional part. An integer
// gets the precision of its digits, like a literal.
fn implicit_cast_type(v Value, t Type) Type {
	if t.typ == .is_numeric || t.typ == .is_decimal {
		if v.typ.typ == .is_numeric || v.typ.typ == .is_decimal {
			return Type{t.typ, v.typ.size, v.typ.scale, false, false}
		}

		if v.typ.typ in [.is_smallint, .is_integer, .is_bigint] && !v.is_null {
			return Type{t.typ, v.str().trim_left('-').len, 0, false, false}
		}
	}

	return Type{t.typ, 0, 0, false, false}
}

fn most_specific_type(t1 Type, t2 Type) !Type {
	t1_category, t1_supertype := t1.typ.supertype()
	t2_category, t2_supertype := t2.typ.supertype()

	if t1_category == t2_category {
		// It's important that we strip the sizes so that anything that needs to be
		// cast (like an integer) will get the correct size.

		if t1_supertype > t2_supertype {
			return Type{t1.typ, 0, 0, false, false}
		}

		return Type{t2.typ, 0, 0, false, false}
	}

	return sqlstate_42601('no supertype of both ${t1} and ${t2}')
}

// new_type is the type with a name that's known to exist, such as from the
// parser. See type_from_name.
fn new_type(name string, size int, scale i16) Type {
	return type_from_name(name, size, scale) or { panic(err) }
}

// type_from_name returns an error if there's no type with the name, such as for
// register_function.
fn type_from_name(name string, size int, scale i16) !Type {
	// The size may appear in the middle of the name, such as
	// "TIME(6) WITH TIME ZONE".
	name_without_size := if name.contains('(') {
		name.all_before('(') + name.all_after(')')
	} else {
		name
	}

	return match name_without_size {
		'BIGINT' {
			Type{.is_bigint, size, scale, false, false}
		}
		'BOOLEAN' {
			Type{.is_boolean, size, scale, false, false}
		}
		'CHARACTER VARYING', 'CHAR VARYING', 'VARCHAR' {
			Type{.is_varchar, size, scale, false, false}
		}
		'CHARACTER', 'CHAR' {
			Type{.is_character, size, scale, false, false}
		}
		'DOUBLE PRECISION', 'FLOAT' {
			Type{.is_double_precision, size, scale, false, false}
		}
		'REAL' {
			Type{.is_real, size, scale, false, false}
		}
		'INT', 'INTEGER' {
			Type{.is_integer, size, scale, false, false}
		}
		'SMALLINT' {
			Type{.is_smallint, size, scale, false, false}
		}
		'DATE' {
			Type{.is_date, size, scale, false, false}
		}
		'TIME', 'TIME WITHOUT TIME ZONE' {
			Type{.is_time_without_time_zone, size, scale, false, false}
		}
		'TIME WITH TIME ZONE' {
			Type{.is_time_with_time_zone, size, scale, false, false}
		}
		'TIMESTAMP', 'TIMESTAMP WITHOUT TIME ZONE' {
			Type{.is_timestamp_without_time_zone, size, scale, false, false}
		}
		'TIMESTAMP WITH TIME ZONE' {
			Type{.is_timestamp_with_time_zone, size, scale, false, false}
		}
		'DECIMAL' {
			Type{.is_decimal, size, scale, false, false}
		}
		'NUMERIC' {
			Type{.is_numeric, size, scale, false, false}
		}
		'CHARACTER LARGE OBJECT', 'CHAR LARGE OBJECT', 'CLOB' {
			Type{.is_clob, size, scale, false, false}
		}
		'BINARY' {
			Type{.is_binary, size, scale, false, false}
		}
		'BINARY VARYING', 'VARBINARY' {
			Type{.is_varbinary, size, scale, false, false}
		}
		'BINARY LARGE OBJECT', 'BLOB' {
			Type{.is_blob, size, scale, false, false}
		}
		'DECFLOAT' {
			Type{.is_decfloat, size, scale, false, false}
		}
		else {
			return sqlstate_42601('unknown type: ${name_without_size}')
		}
	}
}

// size_str is the length of a character string type, with " OCTETS" when it's
// in octets.
fn (t Type) size_str() string {
	return if t.octets { '${t.size} OCTETS' } else { '${t.size}' }
}

// str is the SQL representation, such as ``TIME(3) WITHOUT TIME ZONE``.
pub fn (t Type) str() string {
	mut s := match t.typ {
		.is_bigint {
			'BIGINT'
		}
		.is_boolean {
			'BOOLEAN'
		}
		.is_character {
			if t.size > 0 {
				'CHARACTER(${t.size_str()})'
			} else {
				'CHARACTER'
			}
		}
		.is_double_precision {
			'DOUBLE PRECISION'
		}
		.is_integer {
			'INTEGER'
		}
		.is_real {
			'REAL'
		}
		.is_smallint {
			'SMALLINT'
		}
		.is_varchar {
			if t.size > 0 {
				'CHARACTER VARYING(${t.size_str()})'
			} else {
				'CHARACTER VARYING'
			}
		}
		.is_date {
			'DATE'
		}
		.is_time_without_time_zone {
			'TIME(${t.size}) WITHOUT TIME ZONE'
		}
		.is_time_with_time_zone {
			'TIME(${t.size}) WITH TIME ZONE'
		}
		.is_timestamp_without_time_zone {
			'TIMESTAMP(${t.size}) WITHOUT TIME ZONE'
		}
		.is_timestamp_with_time_zone {
			'TIMESTAMP(${t.size}) WITH TIME ZONE'
		}
		.is_decimal {
			numeric_type_str('DECIMAL', t.size, t.scale)
		}
		.is_numeric {
			numeric_type_str('NUMERIC', t.size, t.scale)
		}
		.is_clob {
			large_object_type_str('CHARACTER LARGE OBJECT', t.size)
		}
		.is_binary {
			'BINARY(${t.size})'
		}
		.is_varbinary {
			'BINARY VARYING(${t.size})'
		}
		.is_blob {
			large_object_type_str('BINARY LARGE OBJECT', t.size)
		}
		.is_decfloat {
			'DECFLOAT(${t.size})'
		}
		.is_interval_year_month, .is_interval_day_time {
			'INTERVAL ${t.interval_qualifier()}'
		}
	}

	if t.not_null {
		s += ' NOT NULL'
	}

	return s
}

// uses_new_encoding is true for a type that's written in a row in a way that
// file format versions before data_types_file_format_version can't read.
fn (t Type) uses_new_encoding() bool {
	return t.typ in [.is_clob, .is_binary, .is_varbinary, .is_blob, .is_decfloat,
		.is_interval_year_month, .is_interval_day_time]
}

// has_time_zone is true for TIME WITH TIME ZONE and TIMESTAMP WITH TIME ZONE.
fn (t Type) has_time_zone() bool {
	return t.typ == .is_time_with_time_zone || t.typ == .is_timestamp_with_time_zone
}

// uses_int is true if the value is stored as an int, see Value.int_value().
pub fn (t Type) uses_int() bool {
	return match t.typ {
		.is_boolean, .is_bigint, .is_smallint, .is_integer {
			true
		}
		else {
			false
		}
	}
}

// uses_f64 is true if the value is stored as an f64, see Value.f64_value().
pub fn (t Type) uses_f64() bool {
	return match t.typ {
		.is_double_precision, .is_real, .is_date, .is_time_with_time_zone,
		.is_time_without_time_zone, .is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			true
		}
		else {
			false
		}
	}
}

// uses_string is true if the value is stored as a string, see Value.string_value().
pub fn (t Type) uses_string() bool {
	return match t.typ {
		.is_varchar, .is_character, .is_clob, .is_binary, .is_varbinary, .is_blob {
			true
		}
		else {
			false
		}
	}
}

fn (t Type) uses_time() bool {
	return match t.typ {
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			true
		}
		else {
			false
		}
	}
}

fn numeric_type_str(typ string, size int, scale i16) string {
	if size == 0 {
		return typ
	}

	if scale == 0 {
		return '${typ}(${size})'
	}

	return '${typ}(${size}, ${scale})'
}

// large_object_type_str is a CHARACTER LARGE OBJECT or BINARY LARGE OBJECT,
// with its length unless it has the maximum length (a size of 0).
fn large_object_type_str(typ string, size int) string {
	if size == 0 {
		return typ
	}

	return '${typ}(${size})'
}
