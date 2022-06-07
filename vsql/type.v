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
}

fn (t SQLType) str() string {
	return match t {
		.is_null { 'NULL' }
		.is_bigint { 'BIGINT' }
		.is_boolean { 'BOOLEAN' }
		.is_character { 'CHARACTER' }
		.is_double_precision { 'DOUBLE PRECISION' }
		.is_integer { 'INTEGER' }
		.is_real { 'REAL' }
		.is_smallint { 'SMALLINT' }
		.is_varchar { 'CHARACTER VARYING' }
	}
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
		else {
			panic(name_without_size)
			Type{}
		}
	}
}

fn (t Type) str() string {
	if t.size > 0 {
		return '${t.typ}($t.size)'
	}

	return t.typ.str()
}

fn (t Type) uses_f64() bool {
	return match t.typ {
		.is_boolean, .is_double_precision, .is_bigint, .is_real, .is_smallint, .is_integer { true }
		.is_null, .is_varchar, .is_character { false }
	}
}

fn (t Type) uses_string() bool {
	return match t.typ {
		.is_null, .is_boolean, .is_double_precision, .is_bigint, .is_real, .is_smallint,
		.is_integer {
			false
		}
		.is_varchar, .is_character {
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
	}
}

fn type_from_number(number u8) Type {
	return new_type(match number {
		0 { 'NULL' }
		1 { 'BOOLEAN' }
		2 { 'BIGINT' }
		3 { 'DOUBLE PRECISION' }
		4 { 'INTEGER' }
		5 { 'REAL' }
		6 { 'SMALLINT' }
		7 { 'CHARACTER VARYING' }
		8 { 'CHARACTER' }
		else { panic(number) }
	}, 0)
}
