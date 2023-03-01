// type.v contains internal definitions and utilities for SQL data types.

module vsql

// Represents a fully-qualified SQL type.
struct Type {
mut:
	// Base SQL type.
	typ SQLType
	// The size specified for the type.
	size int
	// The scale is only for numeric types.
	scale i16
	// Is NOT NULL?
	not_null bool
}

// Represents the fundamental SQL type.
enum SQLType {
	is_bigint // BIGINT
	is_boolean // BOOLEAN
	is_character // CHARACTER(n), CHAR(n), CHARACTER and CHAR
	is_double_precision // DOUBLE PRECISION, FLOAT and FLOAT(n)
	is_integer // INTEGER and INT
	is_real // REAL
	is_smallint // SMALLINT
	is_varchar // CHARACTER VARYING, CHAR VARYING and VARCHAR
	is_date // DATE
	is_time_without_time_zone // TIME, TIME WITHOUT TIME ZONE
	is_time_with_time_zone // TIME WITH TIME ZONE
	is_timestamp_without_time_zone // TIMESTAMP, TIMESTAMP WITHOUT TIME ZONE
	is_timestamp_with_time_zone // TIMESTAMP WITH TIME ZONE
	is_decimal // DECIMAL
	is_numeric // NUMERIC
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
	}
}

fn (t SQLType) is_number() bool {
	return match t {
		.is_bigint, .is_double_precision, .is_integer, .is_real, .is_smallint, .is_numeric { true }
		else { false }
	}
}

fn (t SQLType) is_string() bool {
	return match t {
		.is_character, .is_varchar { true }
		else { false }
	}
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
		.is_character, .is_varchar {
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
		.is_decimal {
			2, 3
		}
		.is_numeric {
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
	}
}

fn most_specific_type(t1 Type, t2 Type) !Type {
	t1_category, t1_supertype := t1.typ.supertype()
	t2_category, t2_supertype := t2.typ.supertype()

	if t1_category == t2_category {
		// It's important that we strip the sizes so that anything that needs to be
		// cast (like an integer) will get the correct size.

		if t1_supertype > t2_supertype {
			return Type{t1.typ, 0, 0, false}
		}

		return Type{t2.typ, 0, 0, false}
	}

	// TODO(elliotchance): Is this the correct SQLSTATE?
	return sqlstate_42601('no supertype of both ${t1} and ${t2}')
}

fn new_type(name string, size int, scale i16) Type {
	name_without_size := name.split('(')[0]

	return match name_without_size {
		'BIGINT' {
			Type{.is_bigint, size, scale, false}
		}
		'BOOLEAN' {
			Type{.is_boolean, size, scale, false}
		}
		'CHARACTER VARYING', 'CHAR VARYING', 'VARCHAR' {
			Type{.is_varchar, size, scale, false}
		}
		'CHARACTER', 'CHAR' {
			Type{.is_character, size, scale, false}
		}
		'DOUBLE PRECISION', 'FLOAT' {
			Type{.is_double_precision, size, scale, false}
		}
		'REAL' {
			Type{.is_real, size, scale, false}
		}
		'INT', 'INTEGER' {
			Type{.is_integer, size, scale, false}
		}
		'SMALLINT' {
			Type{.is_smallint, size, scale, false}
		}
		'DATE' {
			Type{.is_date, size, scale, false}
		}
		'TIME', 'TIME WITHOUT TIME ZONE' {
			Type{.is_time_without_time_zone, size, scale, false}
		}
		'TIME WITH TIME ZONE' {
			Type{.is_time_with_time_zone, size, scale, false}
		}
		'TIMESTAMP', 'TIMESTAMP WITHOUT TIME ZONE' {
			Type{.is_timestamp_without_time_zone, size, scale, false}
		}
		'TIMESTAMP WITH TIME ZONE' {
			Type{.is_timestamp_with_time_zone, size, scale, false}
		}
		'DECIMAL' {
			Type{.is_decimal, size, scale, false}
		}
		'NUMERIC' {
			Type{.is_numeric, size, scale, false}
		}
		else {
			panic(name_without_size)
			Type{}
		}
	}
}

// The SQL representation, such as ``TIME(3) WITHOUT TIME ZONE``.
fn (t Type) str() string {
	mut s := match t.typ {
		.is_bigint {
			'BIGINT'
		}
		.is_boolean {
			'BOOLEAN'
		}
		.is_character {
			if t.size > 0 {
				'CHARACTER(${t.size})'
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
			// TODO(elliotchance): Is this a bug to allow no size for CHARACTER
			//  VARYING? Need to check standard.
			if t.size > 0 {
				'CHARACTER VARYING(${t.size})'
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
			decimal_type_str(t.size, t.scale)
		}
		.is_numeric {
			numeric_type_str(t.size, t.scale)
		}
	}

	if t.not_null {
		s += ' NOT NULL'
	}

	return s
}

fn (t Type) uses_int() bool {
	return match t.typ {
		.is_boolean, .is_bigint, .is_smallint, .is_integer {
			true
		}
		.is_varchar, .is_character, .is_double_precision, .is_real, .is_date,
		.is_time_with_time_zone, .is_time_without_time_zone, .is_timestamp_with_time_zone,
		.is_timestamp_without_time_zone, .is_numeric, .is_decimal {
			false
		}
	}
}

fn (t Type) uses_f64() bool {
	return match t.typ {
		.is_double_precision, .is_real, .is_date, .is_time_with_time_zone,
		.is_time_without_time_zone, .is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			true
		}
		.is_boolean, .is_varchar, .is_character, .is_bigint, .is_smallint, .is_integer,
		.is_numeric, .is_decimal {
			false
		}
	}
}

fn (t Type) uses_string() bool {
	return match t.typ {
		.is_boolean, .is_double_precision, .is_bigint, .is_real, .is_smallint, .is_integer,
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone, .is_numeric, .is_decimal {
			false
		}
		.is_varchar, .is_character {
			true
		}
	}
}

fn (t Type) uses_time() bool {
	return match t.typ {
		.is_boolean, .is_double_precision, .is_bigint, .is_real, .is_smallint, .is_integer,
		.is_varchar, .is_character, .is_numeric, .is_decimal {
			false
		}
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			true
		}
	}
}

fn (t Type) number() u8 {
	return match t.typ {
		.is_boolean { 0 }
		.is_bigint { 1 }
		.is_double_precision { 2 }
		.is_integer { 3 }
		.is_real { 4 }
		.is_smallint { 5 }
		.is_varchar { 6 }
		.is_character { 7 }
		.is_date { 8 }
		.is_time_with_time_zone { 9 }
		.is_time_without_time_zone { 10 }
		.is_timestamp_with_time_zone { 11 }
		.is_timestamp_without_time_zone { 12 }
		.is_decimal { 13 }
		.is_numeric { 14 }
	}
}

fn type_from_number(number u8, size int, scale i16) Type {
	return new_type(match number {
		0 { 'BOOLEAN' }
		1 { 'BIGINT' }
		2 { 'DOUBLE PRECISION' }
		3 { 'INTEGER' }
		4 { 'REAL' }
		5 { 'SMALLINT' }
		6 { 'CHARACTER VARYING(${size})' }
		7 { 'CHARACTER' }
		8 { 'DATE' }
		9 { 'TIME(${size}) WITH TIME ZONE' }
		10 { 'TIME(${size}) WITHOUT TIME ZONE' }
		11 { 'TIMESTAMP(${size}) WITH TIME ZONE' }
		12 { 'TIMESTAMP(${size}) WITHOUT TIME ZONE' }
		13 { decimal_type_str(size, scale) }
		14 { numeric_type_str(size, scale) }
		else { panic(number) }
	}, size, scale)
}

fn decimal_type_str(size int, scale i16) string {
	if size == 0 {
		return 'DECIMAL'
	}

	if scale == 0 {
		return 'DECIMAL(${size})'
	}

	return 'DECIMAL(${size}, ${scale})'
}

fn numeric_type_str(size int, scale i16) string {
	if size == 0 {
		return 'NUMERIC'
	}

	if scale == 0 {
		return 'NUMERIC(${size})'
	}

	return 'NUMERIC(${size}, ${scale})'
}
