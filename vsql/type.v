// type.v contains internal definitions and utilities for SQL data types.

module vsql

struct Type {
mut:
	// TODO(elliotchance): Make these non-mutable.
	typ  SQLType
	size int // the size specified for the type
}

enum SQLType {
	is_null // NULL
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
}

fn new_type(name string, size int) Type {
	name_without_size := name.split('(')[0]

	return match name_without_size {
		'BIGINT' {
			Type{.is_bigint, size}
		}
		'BOOLEAN' {
			Type{.is_boolean, size}
		}
		'CHARACTER VARYING', 'CHAR VARYING', 'VARCHAR' {
			Type{.is_varchar, size}
		}
		'CHARACTER', 'CHAR' {
			Type{.is_character, size}
		}
		'DOUBLE PRECISION', 'FLOAT' {
			Type{.is_double_precision, size}
		}
		'REAL' {
			Type{.is_real, size}
		}
		'INT', 'INTEGER' {
			Type{.is_integer, size}
		}
		'SMALLINT' {
			Type{.is_smallint, size}
		}
		'DATE' {
			Type{.is_date, 0}
		}
		'TIME', 'TIME WITHOUT TIME ZONE' {
			Type{.is_time_without_time_zone, size}
		}
		'TIME WITH TIME ZONE' {
			Type{.is_time_with_time_zone, size}
		}
		'TIMESTAMP', 'TIMESTAMP WITHOUT TIME ZONE' {
			Type{.is_timestamp_without_time_zone, size}
		}
		'TIMESTAMP WITH TIME ZONE' {
			Type{.is_timestamp_with_time_zone, size}
		}
		else {
			panic(name_without_size)
			Type{}
		}
	}
}

fn (t Type) str() string {
	match t.typ {
		.is_null {
			return 'NULL'
		}
		.is_bigint {
			return 'BIGINT'
		}
		.is_boolean {
			return 'BOOLEAN'
		}
		.is_character {
			if t.size > 0 {
				return 'CHARACTER($t.size)'
			}

			return 'CHARACTER'
		}
		.is_double_precision {
			return 'DOUBLE PRECISION'
		}
		.is_integer {
			return 'INTEGER'
		}
		.is_real {
			return 'REAL'
		}
		.is_smallint {
			return 'SMALLINT'
		}
		.is_varchar {
			// TODO(elliotchance): Is this a bug to allow no size for CHARACTER
			//  VARYING? Need to check standard.
			if t.size > 0 {
				return 'CHARACTER VARYING($t.size)'
			}

			return 'CHARACTER VARYING'
		}
		.is_date {
			return 'DATE'
		}
		.is_time_without_time_zone {
			return 'TIME($t.size) WITHOUT TIME ZONE'
		}
		.is_time_with_time_zone {
			return 'TIME($t.size) WITH TIME ZONE'
		}
		.is_timestamp_without_time_zone {
			return 'TIMESTAMP($t.size) WITHOUT TIME ZONE'
		}
		.is_timestamp_with_time_zone {
			return 'TIMESTAMP($t.size) WITH TIME ZONE'
		}
	}
}

fn (t Type) uses_f64() bool {
	return match t.typ {
		.is_boolean, .is_double_precision, .is_bigint, .is_real, .is_smallint, .is_integer,
		.is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			true
		}
		.is_null, .is_varchar, .is_character {
			false
		}
	}
}

fn (t Type) uses_string() bool {
	return match t.typ {
		.is_null, .is_boolean, .is_double_precision, .is_bigint, .is_real, .is_smallint,
		.is_integer, .is_date, .is_time_with_time_zone, .is_time_without_time_zone,
		.is_timestamp_with_time_zone, .is_timestamp_without_time_zone {
			false
		}
		.is_varchar, .is_character {
			true
		}
	}
}

fn (t Type) uses_time() bool {
	return match t.typ {
		.is_null, .is_boolean, .is_double_precision, .is_bigint, .is_real, .is_smallint,
		.is_integer, .is_varchar, .is_character {
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
		.is_null { 0 }
		.is_boolean { 1 }
		.is_bigint { 2 }
		.is_double_precision { 3 }
		.is_integer { 4 }
		.is_real { 5 }
		.is_smallint { 6 }
		.is_varchar { 7 }
		.is_character { 8 }
		.is_date { 9 }
		.is_time_with_time_zone { 10 }
		.is_time_without_time_zone { 11 }
		.is_timestamp_with_time_zone { 12 }
		.is_timestamp_without_time_zone { 13 }
	}
}

fn type_from_number(number u8, size int) Type {
	return new_type(match number {
		0 { 'NULL' }
		1 { 'BOOLEAN' }
		2 { 'BIGINT' }
		3 { 'DOUBLE PRECISION' }
		4 { 'INTEGER' }
		5 { 'REAL' }
		6 { 'SMALLINT' }
		7 { 'CHARACTER VARYING($size)' }
		8 { 'CHARACTER' }
		9 { 'DATE' }
		10 { 'TIME($size) WITH TIME ZONE' }
		11 { 'TIME($size) WITHOUT TIME ZONE' }
		12 { 'TIMESTAMP($size) WITH TIME ZONE' }
		13 { 'TIMESTAMP($size) WITHOUT TIME ZONE' }
		else { panic(number) }
	}, 0)
}
