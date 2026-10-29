module vsql

// ISO/IEC 9075-2:2016(E), 13.5, Data type correspondences
//
// Specify the data type correspondences for SQL data types and host language
// types.

// HostParameterType is the <data type> of a host parameter that has a C data
// type in Table 20, "Data type correspondences for C". The length is only for
// CHARACTER and CHARACTER VARYING.
struct HostParameterType {
	typ    SQLType
	length int
}

// parse_host_parameter_type reads a <host parameter data type>. The types that
// vsql has, but that are 'None' in Table 20 (NUMERIC, DECIMAL, FLOAT, DATE,
// TIME and TIMESTAMP), can't be used (13.3 Syntax Rule 11.b.ii.1).
fn (mut t ModuleTokens) host_parameter_type(name string) !HostParameterType {
	word := t.next_word()
	match word {
		'CHARACTER', 'CHAR', 'VARCHAR' {
			varying := word == 'VARCHAR' || t.accept('VARYING')
			mut length := 1
			if t.accept('(') {
				length = t.length()!
				t.expect(')')!
			} else if varying {
				return sqlstate_42601('host parameter :${name}: CHARACTER VARYING must have a length')
			}

			return HostParameterType{if varying { .is_varchar } else { .is_character }, length}
		}
		'SMALLINT' {
			return HostParameterType{.is_smallint, 0}
		}
		'INTEGER', 'INT' {
			return HostParameterType{.is_integer, 0}
		}
		'BIGINT' {
			return HostParameterType{.is_bigint, 0}
		}
		'REAL' {
			return HostParameterType{.is_real, 0}
		}
		'BOOLEAN' {
			return HostParameterType{.is_boolean, 0}
		}
		'DOUBLE' {
			t.expect('PRECISION')!
			return HostParameterType{.is_double_precision, 0}
		}
		else {
			return sqlstate_42601('host parameter :${name}: the data type must be CHARACTER, CHARACTER VARYING, SMALLINT, INTEGER, BIGINT, REAL, DOUBLE PRECISION or BOOLEAN')
		}
	}
}

// c_declaration is the C data type of a host parameter, such as "long *x".
// A string is a char array, and anything else is a pointer.
fn (t HostParameterType) c_declaration(name string) string {
	return match t.typ {
		.is_character, .is_varchar { 'char ${name}[${t.length + 1}]' }
		.is_smallint { 'short *${name}' }
		.is_integer, .is_boolean { 'long *${name}' }
		.is_bigint { 'long long *${name}' }
		.is_real { 'float *${name}' }
		else { 'double *${name}' }
	}
}

// c_parameter is the struct vsql_m_param (see the C runtime) that binds a host
// parameter to a dynamic parameter. A BOOLEAN is passed as 'TRUE' or 'FALSE'
// (9.3 General Rule 5.e.ii), since libvsql can't cast a number to a BOOLEAN.
fn (t HostParameterType) c_parameter(name string) string {
	return match t.typ {
		.is_character { '{SQL_CHAR, SQL_CHAR, ${t.length}, ${name}, SQL_NTS}' }
		.is_varchar { '{SQL_CHAR, SQL_VARCHAR, ${t.length}, ${name}, SQL_NTS}' }
		.is_smallint { '{SQL_SMALLINT, SQL_SMALLINT, 0, ${name}, 0}' }
		.is_integer { '{SQL_INTEGER, SQL_INTEGER, 0, ${name}, 0}' }
		.is_bigint { '{SQL_BIGINT, SQL_BIGINT, 0, ${name}, 0}' }
		.is_real { '{SQL_REAL, SQL_REAL, 0, ${name}, 0}' }
		.is_boolean {
			'{SQL_CHAR, SQL_BOOLEAN, 0, (SQLPOINTER)(*${name} ? "TRUE" : "FALSE"), SQL_NTS}'
		}
		else { '{SQL_DOUBLE, SQL_DOUBLE, 0, ${name}, 0}' }
	}
}

// c_target is the struct vsql_m_target (see the C runtime) that a value of the
// row of a <select statement: single row> is assigned to. The length of a
// string includes the null character.
fn (t HostParameterType) c_target(name string, has_indicator int) string {
	length := if t.is_string() { t.length + 1 } else { 0 }

	return '{${t.c_code()}, ${length}, ${name}, ${has_indicator}, 0}'
}

// c_code is the C constant of the SQL data type code (Table 28, "Codes used for
// SQL data types in Dynamic SQL"), such as SQL_INTEGER.
fn (t HostParameterType) c_code() string {
	return match t.typ {
		.is_character { 'SQL_CHAR' }
		.is_varchar { 'SQL_VARCHAR' }
		.is_smallint { 'SQL_SMALLINT' }
		.is_integer { 'SQL_INTEGER' }
		.is_bigint { 'SQL_BIGINT' }
		.is_real { 'SQL_REAL' }
		.is_boolean { 'SQL_BOOLEAN' }
		else { 'SQL_DOUBLE' }
	}
}

// c_type is the C data type of an exact numeric, such as "long".
fn (t HostParameterType) c_type() string {
	return t.c_declaration('').all_before(' *')
}

// sql is the SQL data type, such as CHARACTER VARYING(10).
fn (t HostParameterType) sql() string {
	return if t.is_string() { '${t.typ}(${t.length})' } else { t.typ.str() }
}

fn (t HostParameterType) is_string() bool {
	return t.typ in [.is_character, .is_varchar]
}

fn (t HostParameterType) is_exact_numeric() bool {
	return t.typ in [.is_smallint, .is_integer, .is_bigint]
}
