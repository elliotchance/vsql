module vsql

// ISO/IEC 9075-2:2016(E), 13.5, Data type correspondences
//
// Specify the data type correspondences for SQL data types and host language
// types.
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2003(E), 4.8.2, Parameter passing and data type
// correspondences
// ISO/IEC 9075-1:2003(E), 4.8.2.1, General parameter passing and data type
// correspondence information
// ISO/IEC 9075-1:2003(E), 4.8.2.2, Data type correspondences
// ISO/IEC 9075-2:2016(E), 4.1.3, Host language data types

// max_utf8_octets is k, the maximum number of octets of a character in the
// character set of a host parameter (UTF8), which is implementation-defined.
//
// ISO/IEC 9075-2:2016(E), 13.5, Data type correspondences, Table 20
const max_utf8_octets = 4

// HostParameterType is the <data type> of a host parameter that has a C data
// type in Table 20, "Data type correspondences for C". The length (in
// characters) is only for CHARACTER and CHARACTER VARYING.
struct HostParameterType {
	typ    SQLType
	length int
}

// host_parameter_type reads a <host parameter data type>. The types that vsql
// has, but that are 'None' in Table 20 (NUMERIC, DECIMAL, FLOAT, DATE,
// TIME and TIMESTAMP), can't be used. There's no <locator indication>.
//
// ISO/IEC 9075-2:2016(E), 13.3, <externally-invoked procedure>, Syntax Rules, 11.b.ii.1
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
//
// ISO/IEC 9075-2:2016(E), 9.3, Passing a value from a host language to the SQL-server, General Rules, 3 and 4.b
// ISO/IEC 9075-2:2016(E), 9.4, Passing a value from the SQL-server to a host language, General Rules, 2 and 3.b
fn (t HostParameterType) c_declaration(name string) string {
	return match t.typ {
		.is_character, .is_varchar { 'char ${name}[${t.size()}]' }
		.is_smallint { 'short *${name}' }
		.is_integer, .is_boolean { 'long *${name}' }
		.is_bigint { 'long long *${name}' }
		.is_real { 'float *${name}' }
		else { 'double *${name}' }
	}
}

// c_parameter is the struct vsql_m_param (see the C runtime) that binds a host
// parameter to a dynamic parameter. A BOOLEAN is passed as 'TRUE' or 'FALSE',
// since libvsql can't cast a number to a BOOLEAN. Any other value is passed
// as it is.
//
// ISO/IEC 9075-2:2016(E), 9.3, Passing a value from a host language to the SQL-server, General Rules, 5.e.ii and 5.j
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
// row of a <select statement: single row> is assigned to.
fn (t HostParameterType) c_target(name string, has_indicator int) string {
	length := if t.is_string() { t.length } else { 0 }

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

// size is the size in bytes of the char array of a CHARACTER(L) or CHARACTER
// VARYING(L), which is (L+1)*k. The value is up to L*k bytes, then the null character.
//
// ISO/IEC 9075-2:2016(E), 9.4, Passing a value from the SQL-server to a host language, General Rules, 5.b
// ISO/IEC 9075-2:2016(E), 13.5, Data type correspondences, Table 20
fn (t HostParameterType) size() int {
	return (t.length + 1) * max_utf8_octets
}

fn (t HostParameterType) is_string() bool {
	return t.typ in [.is_character, .is_varchar]
}

fn (t HostParameterType) is_exact_numeric() bool {
	return t.typ in [.is_smallint, .is_integer, .is_bigint]
}
