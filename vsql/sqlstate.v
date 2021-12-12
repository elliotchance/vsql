// sqlstate.v contains all the error definitions as they are described by the
// SQLSTATE codes.
//
// The SQL standard is pretty flexible on the individual codes, so I've copied
// the relevant errors code from the definitions in PostgreSQL:
// https://www.postgresql.org/docs/9.4/errcodes-appendix.html

module vsql

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

fn sqlstate_chr(ch byte) int {
	if ch <= `9` {
		return ch - byte(`0`)
	}

	return ch - byte(`A`) + 10
}

fn sqlstate_ord(ch int) byte {
	if ch <= 9 {
		return byte(byte(`0`) + ch)
	}

	return byte(byte(`A`) + (ch - 10))
}

pub fn sqlstate_from_int(code int) string {
	mut b := []byte{len: 5}

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

// Divide by zero.
struct SQLState22012 {
	msg  string
	code int
}

fn sqlstate_22012() IError {
	return SQLState22012{
		code: sqlstate_to_int('22012')
		msg: 'division by zero'
	}
}

// violates non-null constraint
struct SQLState23502 {
	msg  string
	code int
}

fn sqlstate_23502(msg string) IError {
	return SQLState23502{
		code: sqlstate_to_int('23502')
		msg: 'violates non-null constraint: $msg'
	}
}

// syntax error
struct SQLState42601 {
	msg  string
	code int
}

fn sqlstate_42601(message string) IError {
	return SQLState42601{
		code: sqlstate_to_int('42601')
		msg: 'syntax error: $message'
	}
}

// column does not exist
struct SQLState42703 {
	msg  string
	code int
pub:
	column_name string
}

fn sqlstate_42703(column_name string) IError {
	return SQLState42703{
		code: sqlstate_to_int('42703')
		msg: 'no such column: $column_name'
		column_name: column_name
	}
}

// data type mismatch
struct SQLState42804 {
	msg      string
	code     int
	expected string
	actual   string
}

fn sqlstate_42804(msg string, expected string, actual string) IError {
	return SQLState42804{
		code: sqlstate_to_int('42804')
		msg: 'data type mismatch $msg: expected $expected but got $actual'
		expected: expected
		actual: actual
	}
}

// no such table
struct SQLState42P01 {
	msg  string
	code int
pub:
	table_name string
}

fn sqlstate_42p01(table_name string) IError {
	return SQLState42P01{
		code: sqlstate_to_int('42P01')
		msg: 'no such table: $table_name'
		table_name: table_name
	}
}

// duplicate table
struct SQLState42P07 {
	msg  string
	code int
pub:
	table_name string
}

fn sqlstate_42p07(table_name string) IError {
	return SQLState42P07{
		code: sqlstate_to_int('42P07')
		msg: 'duplicate table: $table_name'
		table_name: table_name
	}
}

// No such function
struct SQLState42883 {
	msg  string
	code int
pub:
	function_name string
}

fn sqlstate_42883(function_name string) IError {
	return SQLState42883{
		code: sqlstate_to_int('42883')
		msg: 'function does not exist: $function_name'
		function_name: function_name
	}
}

// Undefined parameter
struct SQLState42P02 {
	msg  string
	code int
pub:
	parameter_name string
}

fn sqlstate_42p02(parameter_name string) IError {
	return SQLState42P02{
		code: sqlstate_to_int('42P02')
		msg: 'parameter does not exist: $parameter_name'
		parameter_name: parameter_name
	}
}

// invalid transaction state: active sql transaction
struct SQLState25001 {
	msg  string
	code int
}

fn sqlstate_25001() IError {
	return SQLState25001{
		code: sqlstate_to_int('25001')
		msg: 'invalid transaction state: active sql transaction'
	}
}

// invalid transaction termination
struct SQLState2D000 {
	msg  string
	code int
}

fn sqlstate_2d000() IError {
	return SQLState2D000{
		code: sqlstate_to_int('2D000')
		msg: 'invalid transaction termination'
	}
}

// invalid transaction initiation
struct SQLState0B000 {
	msg  string
	code int
}

fn sqlstate_0b000(msg string) IError {
	return SQLState0B000{
		code: sqlstate_to_int('0B000')
		msg: 'invalid transaction initiation: $msg'
	}
}

// serialization failure
struct SQLState40001 {
	msg  string
	code int
}

fn sqlstate_40001(message string) IError {
	return SQLState40001{
		code: sqlstate_to_int('40001')
		msg: 'serialization failure: $message'
	}
}

// in failed sql transaction
struct SQLState25P02 {
	msg  string
	code int
}

fn sqlstate_25p02() IError {
	return SQLState25P02{
		code: sqlstate_to_int('25P02')
		msg: 'transaction is aborted, commands ignored until end of transaction block'
	}
}
