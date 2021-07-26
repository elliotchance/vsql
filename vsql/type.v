// type.v contains internal definitions and utilities for SQL data types.

module vsql

struct Type {
	typ  SQLType
	size int // the size/precision specified for the type
}

enum SQLType {
	is_null // NULL
	is_bigint // BIGINT
	is_boolean // BOOLEAN
	is_character // CHARACTER and CHAR
	is_float // FLOAT and DOUBLE PRECISION
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
		.is_float { 'FLOAT' }
		.is_integer { 'INTEGER' }
		.is_real { 'REAL' }
		.is_smallint { 'SMALLINT' }
		.is_varchar { 'CHARACTER VARYING' }
	}
}

fn new_type(name string, size int) Type {
	return match name {
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
		'FLOAT', 'DOUBLE PRECISION' {
			Type{.is_float, size}
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
			panic(name)
			Type{}
		}
	}
}

fn (t Type) str() string {
	return t.typ.str()
}

fn (t Type) uses_f64() bool {
	return match t.typ {
		.is_boolean, .is_float, .is_bigint, .is_real, .is_smallint, .is_integer { true }
		.is_null, .is_varchar, .is_character { false }
	}
}
