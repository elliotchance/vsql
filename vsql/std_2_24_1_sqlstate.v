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

// violated_constraint is the constraint that was violated, for an integrity
// constraint violation (class 23), or a transaction rollback because of one
// (40002). It's none for any other error.
pub fn violated_constraint(err IError) ?Identifier {
	return match err {
		SQLState23502 { err.constraint }
		SQLState23503 { err.constraint }
		SQLState23505 { err.constraint }
		SQLState23514 { err.constraint }
		SQLState40002 { err.constraint }
		else { none }
	}
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

// null value eliminated in set function (warning)
struct SQLState01003 {
	SQLState
}

fn sqlstate_01003() IError {
	return SQLState01003{
		code: sqlstate_to_int('01003')
		msg:  'null value eliminated in set function'
	}
}

// No data (a completion condition, not an error): an UPDATE or DELETE didn't
// match any rows.
struct SQLState02000 {
	SQLState
}

fn sqlstate_02000() IError {
	return SQLState02000{
		code: sqlstate_to_int('02000')
		msg:  'no data'
	}
}

// Warning: string data, right truncation. A CAST removed characters that
// weren't spaces.
struct SQLState01004 {
	SQLState
}

fn sqlstate_01004() IError {
	return SQLState01004{
		code: sqlstate_to_int('01004')
		msg:  'string data, right truncation'
	}
}

// Cardinality violation: a scalar subquery returned more than one row.
struct SQLState21000 {
	SQLState
}

fn sqlstate_21000() IError {
	return SQLState21000{
		code: sqlstate_to_int('21000')
		msg:  'cardinality violation: more than one row returned by a subquery used as an expression'
	}
}

// Invalid cursor state: a cursor isn't in the right state for a statement, such
// as a FETCH of a cursor that isn't open.
struct SQLState24000 {
	SQLState
}

fn sqlstate_24000(msg string) IError {
	return SQLState24000{
		code: sqlstate_to_int('24000')
		msg:  'invalid cursor state: ${msg}'
	}
}

// Invalid cursor name: there isn't a cursor with the name, or it can't be used
// by a statement (such as a positioned DELETE of a cursor that isn't
// updatable).
struct SQLState34000 {
	SQLState
}

fn sqlstate_34000(msg string) IError {
	return SQLState34000{
		code: sqlstate_to_int('34000')
		msg:  'invalid cursor name: ${msg}'
	}
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

// Invalid datetime format.
struct SQLState22007 {
	SQLState
}

fn sqlstate_22007() IError {
	return SQLState22007{
		code: sqlstate_to_int('22007')
		msg:  'invalid datetime format'
	}
}

// Escape character conflict: the ESCAPE of a SIMILAR TO is ":" and the pattern
// has a character class such as "[:ALPHA:]".
struct SQLState2200B {
	SQLState
}

fn sqlstate_2200b() IError {
	return SQLState2200B{
		code: sqlstate_to_int('2200B')
		msg:  'escape character conflict'
	}
}

// Invalid use of escape character: the ESCAPE of a SIMILAR TO is a special
// character, and the pattern uses it other than to escape a character.
struct SQLState2200C {
	SQLState
}

fn sqlstate_2200c() IError {
	return SQLState2200C{
		code: sqlstate_to_int('2200C')
		msg:  'invalid use of escape character'
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

// Substring error.
struct SQLState22011 {
	SQLState
}

fn sqlstate_22011() IError {
	return SQLState22011{
		code: sqlstate_to_int('22011')
		msg:  'substring error'
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

// Invalid argument for natural logarithm.
struct SQLState2201E {
	SQLState
}

fn sqlstate_2201e() IError {
	return SQLState2201E{
		code: sqlstate_to_int('2201E')
		msg:  'invalid argument for natural logarithm'
	}
}

// Invalid argument for power function.
struct SQLState2201F {
	SQLState
}

fn sqlstate_2201f() IError {
	return SQLState2201F{
		code: sqlstate_to_int('2201F')
		msg:  'invalid argument for power function'
	}
}

// Invalid character value for cast.
struct SQLState22018 {
	SQLState
}

fn sqlstate_22018() IError {
	return SQLState22018{
		code: sqlstate_to_int('22018')
		msg:  'invalid character value for cast'
	}
}

// Invalid escape character: the ESCAPE of a LIKE isn't exactly one character.
struct SQLState22019 {
	SQLState
}

fn sqlstate_22019() IError {
	return SQLState22019{
		code: sqlstate_to_int('22019')
		msg:  'invalid escape character'
	}
}

// Invalid regular expression.
struct SQLState2201B {
	SQLState
}

fn sqlstate_2201b() IError {
	return SQLState2201B{
		code: sqlstate_to_int('2201B')
		msg:  'invalid regular expression'
	}
}

// Invalid row count in fetch first clause.
struct SQLState2201W {
	SQLState
}

fn sqlstate_2201w() IError {
	return SQLState2201W{
		code: sqlstate_to_int('2201W')
		msg:  'invalid row count in fetch first clause'
	}
}

// Invalid row count in result offset clause.
struct SQLState2201X {
	SQLState
}

fn sqlstate_2201x() IError {
	return SQLState2201X{
		code: sqlstate_to_int('2201X')
		msg:  'invalid row count in result offset clause'
	}
}

// Invalid escape sequence: the escape character in a LIKE pattern isn't
// followed by "%", "_" or itself.
struct SQLState22025 {
	SQLState
}

fn sqlstate_22025() IError {
	return SQLState22025{
		code: sqlstate_to_int('22025')
		msg:  'invalid escape sequence'
	}
}

// Trim error.
struct SQLState22027 {
	SQLState
}

fn sqlstate_22027() IError {
	return SQLState22027{
		code: sqlstate_to_int('22027')
		msg:  'trim error'
	}
}

// violates non-null constraint
struct SQLState23502 {
	SQLState
	constraint Identifier
}

fn sqlstate_23502(t Table, column_name string) IError {
	return SQLState23502{
		code:       sqlstate_to_int('23502')
		msg:        'violates non-null constraint: column ${column_name}'
		constraint: t.constraint_identifier(t.not_null_names[column_name])
	}
}

// violates foreign key constraint
struct SQLState23503 {
	SQLState
	constraint Identifier
}

fn sqlstate_23503(msg string, constraint Identifier) IError {
	return SQLState23503{
		code:       sqlstate_to_int('23503')
		msg:        'violates foreign key constraint: ${msg}'
		constraint: constraint
	}
}

// violates unique constraint
struct SQLState23505 {
	SQLState
	constraint Identifier
}

fn sqlstate_23505(msg string, constraint Identifier) IError {
	return SQLState23505{
		code:       sqlstate_to_int('23505')
		msg:        'violates unique constraint: ${msg}'
		constraint: constraint
	}
}

// violates check constraint
struct SQLState23514 {
	SQLState
	constraint Identifier
}

fn sqlstate_23514(msg string, constraint Identifier) IError {
	return SQLState23514{
		code:       sqlstate_to_int('23514')
		msg:        'violates check constraint: ${msg}'
		constraint: constraint
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

// Duplicate cursor: a cursor has already been declared with the name.
struct SQLState42P03 {
	SQLState
pub:
	cursor_name string
}

fn sqlstate_42p03(cursor_name string) IError {
	return SQLState42P03{
		code:        sqlstate_to_int('42P03')
		msg:         'duplicate cursor: ${cursor_name}'
		cursor_name: cursor_name
	}
}

// ambiguous column
struct SQLState42702 {
	SQLState
pub:
	column_name string
}

fn sqlstate_42702(column_name string) IError {
	return SQLState42702{
		code:        sqlstate_to_int('42702')
		msg:         'ambiguous column: ${column_name}'
		column_name: column_name
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

// no such object, such as a constraint
struct SQLState42704 {
	SQLState
pub:
	// entity_type is 'constraint'
	entity_type string
	// entity_name is the name of the object
	entity_name string
}

fn sqlstate_42704(entity_type string, entity_name string) IError {
	return SQLState42704{
		code:        sqlstate_to_int('42704')
		msg:         'no such ${entity_type}: ${entity_name}'
		entity_type: entity_type
		entity_name: entity_name
	}
}

// duplicate object, such as a constraint
struct SQLState42710 {
	SQLState
pub:
	// entity_type is 'constraint'
	entity_type string
	// entity_name is the name of the object
	entity_name string
}

fn sqlstate_42710(entity_type string, entity_name string) IError {
	return SQLState42710{
		code:        sqlstate_to_int('42710')
		msg:         'duplicate ${entity_type}: ${entity_name}'
		entity_type: entity_type
		entity_name: entity_name
	}
}

// grouping error
struct SQLState42803 {
	SQLState
pub:
	column_name string
}

fn sqlstate_42803(column_name string) IError {
	return SQLState42803{
		code:        sqlstate_to_int('42803')
		msg:         'column ${column_name} must be in the GROUP BY clause or used in an aggregate function'
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

// invalid foreign key
struct SQLState42830 {
	SQLState
}

fn sqlstate_42830(msg string) IError {
	return SQLState42830{
		code: sqlstate_to_int('42830')
		msg:  'invalid foreign key: ${msg}'
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

// generated always (an identity column that is GENERATED ALWAYS can only be
// assigned DEFAULT)
struct SQLState428C9 {
	SQLState
pub:
	column_name string
}

fn sqlstate_428c9(column_name string) IError {
	return SQLState428C9{
		code:        sqlstate_to_int('428C9')
		msg:         'cannot assign a value other than DEFAULT to column ${column_name}, which is GENERATED ALWAYS'
		column_name: column_name
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

// duplicate table or sequence
struct SQLState42P07 {
	SQLState
pub:
	// entity_type is 'table' or 'sequence'
	entity_type string
	// entity_name is the table name, sequence name, etc
	entity_name string
}

fn sqlstate_42p07(entity_type string, entity_name string) IError {
	return SQLState42P07{
		code:        sqlstate_to_int('42P07')
		msg:         'duplicate ${entity_type}: ${entity_name}'
		entity_type: entity_type
		entity_name: entity_name
	}
}

// invalid column reference
struct SQLState42P10 {
	SQLState
pub:
	column_name string
}

fn sqlstate_42p10(column_name string) IError {
	return SQLState42P10{
		code:        sqlstate_to_int('42P10')
		msg:         'column ${column_name} must be in the select list to be used in ORDER BY with SELECT DISTINCT'
		column_name: column_name
	}
}

// A function with the same name and argument types already exists.
struct SQLState42723 {
	SQLState
}

fn sqlstate_42723(msg string) IError {
	return SQLState42723{
		code: sqlstate_to_int('42723')
		msg:  'duplicate function: ${msg}'
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

// sql-client unable to establish sql-connection
struct SQLState08001 {
	SQLState
}

fn sqlstate_08001(msg string) IError {
	return SQLState08001{
		code: sqlstate_to_int('08001')
		msg:  'sql-client unable to establish sql-connection: ${msg}'
	}
}

// connection name in use
struct SQLState08002 {
	SQLState
}

fn sqlstate_08002(msg string) IError {
	return SQLState08002{
		code: sqlstate_to_int('08002')
		msg:  'connection name in use: ${msg}'
	}
}

// connection does not exist
struct SQLState08003 {
	SQLState
}

fn sqlstate_08003(msg string) IError {
	return SQLState08003{
		code: sqlstate_to_int('08003')
		msg:  'connection does not exist: ${msg}'
	}
}

// feature not supported: multiple server transactions
struct SQLState0A001 {
	SQLState
}

fn sqlstate_0a001() IError {
	return SQLState0A001{
		code: sqlstate_to_int('0A001')
		msg:  'feature not supported: multiple server transactions'
	}
}

// invalid authorization specification
struct SQLState28000 {
	SQLState
}

fn sqlstate_28000(msg string) IError {
	return SQLState28000{
		code: sqlstate_to_int('28000')
		msg:  'invalid authorization specification: ${msg}'
	}
}

// invalid connection name
struct SQLState2E000 {
	SQLState
}

fn sqlstate_2e000(msg string) IError {
	return SQLState2E000{
		code: sqlstate_to_int('2E000')
		msg:  'invalid connection name: ${msg}'
	}
}

// warning: invalid number of conditions
struct SQLState01012 {
	SQLState
}

fn sqlstate_01012() IError {
	return SQLState01012{
		code: sqlstate_to_int('01012')
		msg:  'invalid number of conditions'
	}
}

// invalid condition number
struct SQLState35000 {
	SQLState
}

fn sqlstate_35000() IError {
	return SQLState35000{
		code: sqlstate_to_int('35000')
		msg:  'invalid condition number'
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

// read-only sql transaction
struct SQLState25006 {
	SQLState
}

fn sqlstate_25006(msg string) IError {
	return SQLState25006{
		code: sqlstate_to_int('25006')
		msg:  'read-only sql transaction: ${msg}'
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

// transaction rollback: integrity constraint violation
struct SQLState40002 {
	SQLState
	constraint Identifier
}

fn sqlstate_40002(message string, constraint Identifier) IError {
	return SQLState40002{
		code:       sqlstate_to_int('40002')
		msg:        'integrity constraint violation: ${message}'
		constraint: constraint
	}
}

// feature not supported, such as a file that needs a different version of vsql
// to be opened.
struct SQLState0A000 {
	SQLState
}

fn sqlstate_0a000(msg string) IError {
	return SQLState0A000{
		code: sqlstate_to_int('0A000')
		msg:  msg
	}
}

// insufficient privilege, such as changing the INFORMATION_SCHEMA.
struct SQLState42501 {
	SQLState
}

fn sqlstate_42501(msg string) IError {
	return SQLState42501{
		code: sqlstate_to_int('42501')
		msg:  'insufficient privilege: ${msg}'
	}
}

// duplicate catalog
struct SQLState42P04 {
	SQLState
pub:
	catalog_name string
}

fn sqlstate_42p04(catalog_name string) IError {
	return SQLState42P04{
		code:         sqlstate_to_int('42P04')
		msg:          'duplicate catalog: ${catalog_name}'
		catalog_name: catalog_name
	}
}

// invalid name, such as an identifier passed to the API that can't be parsed.
struct SQLState42602 {
	SQLState
}

fn sqlstate_42602(msg string) IError {
	return SQLState42602{
		code: sqlstate_to_int('42602')
		msg:  msg
	}
}

// program limit exceeded, such as a key that doesn't fit in a page.
struct SQLState54000 {
	SQLState
}

fn sqlstate_54000(msg string) IError {
	return SQLState54000{
		code: sqlstate_to_int('54000')
		msg:  msg
	}
}

// io error: reading, writing or locking a file failed.
struct SQLState58030 {
	SQLState
}

fn sqlstate_58030(msg string) IError {
	return SQLState58030{
		code: sqlstate_to_int('58030')
		msg:  msg
	}
}

// io_error returns err as a 58030 io error, unless it already has a SQLSTATE.
// Errors from the os module have no SQLSTATE (some have an errno as their
// code).
fn io_error(err IError) IError {
	if err.code() >= sqlstate_to_int('01000') {
		return err
	}

	return sqlstate_58030(err.msg())
}

// internal error: something that can't happen, unless there's a bug in vsql.
struct SQLStateXX000 {
	SQLState
}

fn sqlstate_xx000(msg string) IError {
	return SQLStateXX000{
		code: sqlstate_to_int('XX000')
		msg:  msg
	}
}

// data corrupted: a file isn't a vsql database, or its contents are not valid.
struct SQLStateXX001 {
	SQLState
}

fn sqlstate_xx001(msg string) IError {
	return SQLStateXX001{
		code: sqlstate_to_int('XX001')
		msg:  msg
	}
}
