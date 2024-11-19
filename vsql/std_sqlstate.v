module vsql

// ISO/IEC 9075-2:2016(E), 24.1, SQLSTATE
//
// The SQL standard is pretty flexible on the individual codes, so I've copied
// the relevant errors code from the definitions in PostgreSQL:
// https://www.postgresql.org/docs/9.4/errcodes-appendix.html

// sqlstate_to_int converts the 5 character SQLSTATE code (such as "42P01") into
// an integer representation. The returned value can be converted back to its
// respective string by using sqlstate_from_int().
//
// If code is invalid the result will be unexpected.
pub fn sqlstate_to_int(code string) int {
	upper_code := code.to_upper()

	return sqlstate_chr(upper_code[0]) * 1679616 + sqlstate_chr(upper_code[1]) * 46656 +
		sqlstate_chr(upper_code[2]) * 1296 + sqlstate_chr(upper_code[3]) * 36 +
		sqlstate_chr(upper_code[4])
}

fn sqlstate_chr(ch u8) int {
	if ch <= `9` {
		return ch - u8(`0`)
	}

	return ch - u8(`A`) + 10
}

fn sqlstate_ord(ch int) u8 {
	if ch <= 9 {
		return u8(`0`) + u8(ch)
	}

	return u8(`A`) + (u8(ch) - 10)
}

// sqlstate_from_int performs the inverse operation of sqlstate_to_int.
pub fn sqlstate_from_int(code int) string {
	mut b := []u8{len: 5}

	mut i := 0
	mut left := code
	for m in [1679616, 46656, 1296, 36, 1] {
		x := int(left / m)
		b[i] = sqlstate_ord(x)
		left -= x * m
		i++
	}

	return b.bytestr()
}

// SQLState is a compatible V error. It contains a human-readable message and'
// the SQLSTATE code.
struct SQLState {
	msg  string
	code int
}

// Provides the human-readable message.
fn (err SQLState) msg() string {
	return err.msg
}

// Is the integer representation of the SQLSTATE. Convert to a string with
// sqlstate_from_int.
fn (err SQLState) code() int {
	return err.code
}

// string data right truncation - the character value is too long for the
// destination.
struct SQLState22001 {
	SQLState
	to Type
}

fn sqlstate_22001(to Type) IError {
	return SQLState22001{
		code: sqlstate_to_int('22001')
		msg:  'string data right truncation for ${to}'
		to:   to
	}
}

// Numeric value out of range.
struct SQLState22003 {
	SQLState
}

fn sqlstate_22003() IError {
	return SQLState22003{
		code: sqlstate_to_int('22003')
		msg:  'numeric value out of range'
	}
}

// Sequence generator limit exceeded.
struct SQLState2200H {
	SQLState
	generator_name string
}

fn sqlstate_2200h(generator_name string) IError {
	return SQLState2200H{
		code: sqlstate_to_int('2200H')
		msg:  'sequence generator limit exceeded: ${generator_name}'
	}
}

// Divide by zero.
struct SQLState22012 {
	SQLState
}

fn sqlstate_22012() IError {
	return SQLState22012{
		code: sqlstate_to_int('22012')
		msg:  'division by zero'
	}
}

// violates non-null constraint
struct SQLState23502 {
	SQLState
}

fn sqlstate_23502(msg string) IError {
	return SQLState23502{
		code: sqlstate_to_int('23502')
		msg:  'violates non-null constraint: ${msg}'
	}
}

// dependent objects still exist
struct SQLState2BP01 {
	SQLState
pub:
	object_name string
}

fn sqlstate_2bp01(object_name string) IError {
	return SQLState2BP01{
		code:        sqlstate_to_int('2BP01')
		msg:         'dependent objects still exist on ${object_name}'
		object_name: object_name
	}
}

// catalog name is invalid
struct SQLState3D000 {
	SQLState
pub:
	catalog_name string
}

fn sqlstate_3d000(catalog_name string) IError {
	return SQLState3D000{
		code:         sqlstate_to_int('3D000')
		msg:          'invalid catalog name: ${catalog_name}'
		catalog_name: catalog_name
	}
}

// schema name is invalid
struct SQLState3F000 {
	SQLState
pub:
	schema_name string
}

fn sqlstate_3f000(schema_name string) IError {
	return SQLState3F000{
		code:        sqlstate_to_int('3F000')
		msg:         'invalid schema name: ${schema_name}'
		schema_name: schema_name
	}
}

// syntax error
struct SQLState42601 {
	SQLState
}

fn sqlstate_42601(message string) IError {
	return SQLState42601{
		code: sqlstate_to_int('42601')
		msg:  'syntax error: ${message}'
	}
}

// column does not exist
struct SQLState42703 {
	SQLState
pub:
	column_name string
}

fn sqlstate_42703(column_name string) IError {
	return SQLState42703{
		code:        sqlstate_to_int('42703')
		msg:         'no such column: ${column_name}'
		column_name: column_name
	}
}

// data type mismatch
struct SQLState42804 {
	SQLState
	expected string
	actual   string
}

fn sqlstate_42804(msg string, expected string, actual string) IError {
	return SQLState42804{
		code:     sqlstate_to_int('42804')
		msg:      'data type mismatch ${msg}: expected ${expected} but got ${actual}'
		expected: expected
		actual:   actual
	}
}

// cannot coerce
struct SQLState42846 {
	SQLState
	from Type
	to   Type
}

fn sqlstate_42846(from Type, to Type) IError {
	return SQLState42846{
		code: sqlstate_to_int('42846')
		msg:  'cannot coerce ${from} to ${to}'
		from: from
		to:   to
	}
}

// no such table
struct SQLState42P01 {
	SQLState
pub:
	// entity_type is 'table' or 'sequence'
	entity_type string
	// entity_name is the table name, sequence name, etc
	entity_name string
}

fn sqlstate_42p01(entity_type string, entity_name string) IError {
	return SQLState42P01{
		code:        sqlstate_to_int('42P01')
		msg:         'no such ${entity_type}: ${entity_name}'
		entity_type: entity_type
		entity_name: entity_name
	}
}

// duplicate schema
struct SQLState42P06 {
	SQLState
pub:
	schema_name string
}

fn sqlstate_42p06(schema_name string) IError {
	return SQLState42P06{
		code:        sqlstate_to_int('42P06')
		msg:         'duplicate schema: ${schema_name}'
		schema_name: schema_name
	}
}

// duplicate table
struct SQLState42P07 {
	SQLState
pub:
	table_name string
}

fn sqlstate_42p07(table_name string) IError {
	return SQLState42P07{
		code:       sqlstate_to_int('42P07')
		msg:        'duplicate table: ${table_name}'
		table_name: table_name
	}
}

// No such function or operator (since operators are functions).
struct SQLState42883 {
	SQLState
}

fn sqlstate_42883(msg string) IError {
	return SQLState42883{
		code: sqlstate_to_int('42883')
		msg:  msg
	}
}

// Undefined parameter
struct SQLState42P02 {
	SQLState
pub:
	parameter_name string
}

fn sqlstate_42p02(parameter_name string) IError {
	return SQLState42P02{
		code:           sqlstate_to_int('42P02')
		msg:            'parameter does not exist: ${parameter_name}'
		parameter_name: parameter_name
	}
}

// invalid transaction state: active sql transaction
struct SQLState25001 {
	SQLState
}

fn sqlstate_25001() IError {
	return SQLState25001{
		code: sqlstate_to_int('25001')
		msg:  'invalid transaction state: active sql transaction'
	}
}

// invalid transaction termination
struct SQLState2D000 {
	SQLState
}

fn sqlstate_2d000() IError {
	return SQLState2D000{
		code: sqlstate_to_int('2D000')
		msg:  'invalid transaction termination'
	}
}

// invalid transaction initiation
struct SQLState0B000 {
	SQLState
}

fn sqlstate_0b000(msg string) IError {
	return SQLState0B000{
		code: sqlstate_to_int('0B000')
		msg:  'invalid transaction initiation: ${msg}'
	}
}

// serialization failure
struct SQLState40001 {
	SQLState
}

fn sqlstate_40001(message string) IError {
	return SQLState40001{
		code: sqlstate_to_int('40001')
		msg:  'serialization failure: ${message}'
	}
}

// in failed sql transaction
struct SQLState25P02 {
	SQLState
}

fn sqlstate_25p02() IError {
	return SQLState25P02{
		code: sqlstate_to_int('25P02')
		msg:  'transaction is aborted, commands ignored until end of transaction block'
	}
}
