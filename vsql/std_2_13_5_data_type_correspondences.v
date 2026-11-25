module vsql

// ISO/IEC 9075-2:2023, 13.5, Data type correspondences
//
// Specify the data type correspondences for SQL data types and host language
// types.
//
// The concepts are described by:
//
// ISO/IEC 9075-1:2023, 4.10.3, Parameter passing and data type
// correspondences
// ISO/IEC 9075-1:2023, 4.10.3.1, General parameter passing and data type
// correspondence information
// ISO/IEC 9075-1:2023, 4.10.3.2, Data type correspondences
// ISO/IEC 9075-2:2023, 4.2.3, Host language data types

// max_utf8_octets is k, the maximum number of octets of a character in the
// character set of a host parameter (UTF8), which is implementation-defined.
//
// ISO/IEC 9075-2:2023, 13.5, Data type correspondences, Table 20
const max_utf8_octets = 4

// HostParameterType is the <data type> of a host parameter that has a C data
// type in Table 20, "Data type correspondences for C". The length is only for
// CHARACTER, CHARACTER VARYING and CHARACTER LARGE OBJECT (in characters), and
// BINARY, BINARY VARYING and BINARY LARGE OBJECT (in octets).
struct HostParameterType {
	typ    SQLType
	length int
}

// host_parameter_type reads a <host parameter data type>. The types that vsql
// has, but that are 'None' in Table 20 (NUMERIC, DECIMAL, FLOAT, DATE,
// TIME and TIMESTAMP), can't be used. There's no <locator indication>, and the
// <large object length> of a CHARACTER LARGE OBJECT or BINARY LARGE OBJECT
// must be a number of characters (or octets), without K, M or G.
//
// ISO/IEC 9075-2:2023, 13.3, <externally-invoked procedure>, Syntax Rules, 11.b.ii.1
fn (mut t ModuleTokens) host_parameter_type(name string) !HostParameterType {
	word := t.next_word()
	match word {
		'CLOB', 'BLOB' {
			return t.large_object_type(name, word == 'CLOB')
		}
		'CHARACTER', 'CHAR', 'VARCHAR' {
			if word != 'VARCHAR' && t.accept('LARGE') {
				t.expect('OBJECT')!
				return t.large_object_type(name, true)
			}
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
		'BINARY', 'VARBINARY' {
			if word == 'BINARY' && t.accept('LARGE') {
				t.expect('OBJECT')!
				return t.large_object_type(name, false)
			}
			varying := word == 'VARBINARY' || t.accept('VARYING')
			mut length := 1
			if t.accept('(') {
				length = t.length()!
				t.expect(')')!
			} else if varying {
				return sqlstate_42601('host parameter :${name}: BINARY VARYING must have a length')
			}

			return HostParameterType{if varying { .is_varbinary } else { .is_binary }, length}
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
			return sqlstate_42601('host parameter :${name}: the data type must be CHARACTER, CHARACTER VARYING, CHARACTER LARGE OBJECT, BINARY, BINARY VARYING, BINARY LARGE OBJECT, SMALLINT, INTEGER, BIGINT, REAL, DOUBLE PRECISION or BOOLEAN')
		}
	}
}

// large_object_type reads the length of a CHARACTER LARGE OBJECT (if is_clob
// is true) or BINARY LARGE OBJECT, which must have one, since it's the size of
// the data portion of its C struct.
fn (mut t ModuleTokens) large_object_type(name string, is_clob bool) !HostParameterType {
	typ := if is_clob { SQLType.is_clob } else { SQLType.is_blob }
	if !t.accept('(') {
		return sqlstate_42601('host parameter :${name}: ${typ} must have a length')
	}
	length := t.length()!
	t.expect(')')!

	return HostParameterType{typ, length}
}

// c_declaration is the C data type of a host parameter, such as "long *x".
// A string is a char array, and anything else is a pointer. A BINARY(L) is a
// char array of L octets. A BINARY VARYING(L) is a struct (with a length and
// the data, see vsql_m_varbinary in the C runtime), which each program declares
// itself, so it's passed as a void pointer, since two struct types without a
// tag aren't compatible in C. A CHARACTER LARGE OBJECT(L) and BINARY LARGE
// OBJECT(L) are the same kind of struct (with L*k and L octets).
//
// ISO/IEC 9075-2:2023, 9.3, Passing a value from a host language to the SQL-server, General Rules, 3 and 4.b
// ISO/IEC 9075-2:2023, 9.4, Passing a value from the SQL-server to a host language, General Rules, 2 and 3.b
// ISO/IEC 9075-2:2023, 13.5, Data type correspondences, Table 22
fn (t HostParameterType) c_declaration(name string) string {
	return match t.typ {
		.is_character, .is_varchar { 'char ${name}[${t.size()}]' }
		.is_binary { 'char ${name}[${t.length}]' }
		.is_varbinary, .is_clob, .is_blob { 'void *${name}' }
		.is_smallint { 'short *${name}' }
		.is_integer, .is_boolean { 'long *${name}' }
		.is_bigint { 'long long *${name}' }
		.is_real { 'float *${name}' }
		else { 'double *${name}' }
	}
}

// c_parameter is the struct vsql_m_param (see the C runtime) that binds a host
// parameter to a dynamic parameter. A BOOLEAN is passed as 'TRUE' or 'FALSE',
// since libvsql can't cast a number to a BOOLEAN. An INTEGER is passed as a
// VSQL_M_LONG. A BINARY(L) is its L octets, and a BINARY VARYING(L) is the
// octets of its data portion, with the length of its length portion. A BINARY
// LARGE OBJECT(L) is the same as a BINARY VARYING(L). The length portion of a
// CHARACTER LARGE OBJECT(L) is in characters, so the C runtime works out the
// octets of that many characters (see vsql_m_clob_octets). Any other value is
// passed as it is.
//
// ISO/IEC 9075-2:2023, 9.3, Passing a value from a host language to the SQL-server, General Rules, 5.e.ii and 5.j
// ISO/IEC 9075-2:2023, 9.3, Passing a value from a host language to the SQL-server, General Rules, 5.h.i and 5.h.ii
// ISO/IEC 9075-2:2023, 9.3, Passing a value from a host language to the SQL-server, General Rules, 5.f, 5.f.i, 5.f.i.1 and 5.f.ii
fn (t HostParameterType) c_parameter(name string) string {
	return match t.typ {
		.is_blob {
			'{SQL_BLOB, SQL_BLOB, ${t.length}, ((struct vsql_m_varbinary *)${name})->data, (SQLINTEGER)((struct vsql_m_varbinary *)${name})->length}'
		}
		.is_clob {
			'{SQL_CLOB, SQL_CLOB, ${t.length}, vsql_m_clob_data(${name}), vsql_m_clob_octets(${name}, ${t.length * max_utf8_octets})}'
		}
		.is_binary {
			'{SQL_BINARY, SQL_BINARY, ${t.length}, ${name}, ${t.length}}'
		}
		.is_varbinary {
			'{SQL_VARBINARY, SQL_VARBINARY, ${t.length}, ((struct vsql_m_varbinary *)${name})->data, (SQLINTEGER)((struct vsql_m_varbinary *)${name})->length}'
		}
		.is_character { '{SQL_CHAR, SQL_CHAR, ${t.length}, ${name}, SQL_NTS}' }
		.is_varchar { '{SQL_CHAR, SQL_VARCHAR, ${t.length}, ${name}, SQL_NTS}' }
		.is_smallint { '{SQL_SMALLINT, SQL_SMALLINT, 0, ${name}, 0}' }
		.is_integer { '{VSQL_M_LONG, SQL_INTEGER, 0, ${name}, 0}' }
		.is_bigint { '{SQL_BIGINT, SQL_BIGINT, 0, ${name}, 0}' }
		.is_real { '{SQL_REAL, SQL_REAL, 0, ${name}, 0}' }
		.is_boolean {
			'{SQL_CHAR, SQL_BOOLEAN, 0, (SQLPOINTER)(*${name} ? "TRUE" : "FALSE"), SQL_NTS}'
		}
		else { '{SQL_DOUBLE, SQL_DOUBLE, 0, ${name}, 0}' }
	}
}

// c_target is the struct vsql_m_target (see the C runtime) that a value of the
// row of a <select statement: single row> is assigned to. max_indicator is 0
// (zero) if it has no indicator parameter.
fn (t HostParameterType) c_target(name string, max_indicator int) string {
	length := if t.is_string() || t.is_binary() || t.is_large_object() { t.length } else { 0 }

	return '{${t.c_code()}, ${length}, ${name}, ${max_indicator}, 0}'
}

// max_indicator is the largest length of a string that an indicator parameter
// of this type can contain. The C runtime counts it in a SQLINTEGER, which fits
// in an INTEGER or BIGINT.
//
// ISO/IEC 9075-2:2023, 9.1, Retrieval assignment, General Rules, 5.a and 6.a
fn (t HostParameterType) max_indicator() int {
	return if t.typ == .is_smallint { 32767 } else { 2147483647 }
}

// c_code is the C constant of the SQL data type code (Table 28, "Codes used for
// SQL data types in Dynamic SQL"), such as SQL_INTEGER.
fn (t HostParameterType) c_code() string {
	return match t.typ {
		.is_character { 'SQL_CHAR' }
		.is_varchar { 'SQL_VARCHAR' }
		.is_binary { 'SQL_BINARY' }
		.is_varbinary { 'SQL_VARBINARY' }
		.is_clob { 'SQL_CLOB' }
		.is_blob { 'SQL_BLOB' }
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
	return if t.is_string() || t.is_binary() || t.is_large_object() {
		'${t.typ}(${t.length})'
	} else {
		t.typ.str()
	}
}

// size is the size in bytes of the char array of a CHARACTER(L) or CHARACTER
// VARYING(L), which is (L+1)*k. The value is up to L*k bytes, then the null character.
//
// ISO/IEC 9075-2:2023, 9.4, Passing a value from the SQL-server to a host language, General Rules, 5.b
// ISO/IEC 9075-2:2023, 13.5, Data type correspondences, Table 20
fn (t HostParameterType) size() int {
	return (t.length + 1) * max_utf8_octets
}

fn (t HostParameterType) is_string() bool {
	return t.typ in [.is_character, .is_varchar]
}

// is_binary is true for BINARY and BINARY VARYING.
fn (t HostParameterType) is_binary() bool {
	return t.typ in [.is_binary, .is_varbinary]
}

// is_large_object is true for CHARACTER LARGE OBJECT and BINARY LARGE OBJECT.
fn (t HostParameterType) is_large_object() bool {
	return t.typ in [.is_clob, .is_blob]
}

fn (t HostParameterType) is_exact_numeric() bool {
	return t.typ in [.is_smallint, .is_integer, .is_bigint]
}
