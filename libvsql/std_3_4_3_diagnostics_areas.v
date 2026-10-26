module main

import vsql

// ISO/IEC 9075-3:2003(E), 4.3, Diagnostics areas in SQL/CLI
//
// Each handle has a diagnostics area that is emptied at the start of each CLI
// routine (other than GetDiagRec) that's given the handle. The conditions are
// read with GetDiagRec.

struct DiagnosticRecord {
	sqlstate string
	msg      string
}

struct Diagnostics {
mut:
	records []DiagnosticRecord
}

// CLIError is an exception condition raised by a CLI routine itself, rather
// than one from executing an SQL statement.
struct CLIError {
	Error
	sqlstate string
	message  string
}

fn (err CLIError) msg() string {
	return err.message
}

fn cli_error(sqlstate string, msg string) IError {
	return CLIError{
		sqlstate: sqlstate
		message:  msg
	}
}

fn (mut d Diagnostics) clear() {
	d.records = []
}

// warning raises a completion condition, such as "01004 string data, right
// truncation".
fn (mut d Diagnostics) warning(sqlstate string, msg string) i16 {
	d.records << DiagnosticRecord{sqlstate, msg}

	return sql_success_with_info
}

// error raises an exception condition. err is either a CLIError or an error
// from vsql (which has the SQLSTATE as its code).
fn (mut d Diagnostics) error(err IError) i16 {
	sqlstate := if err is CLIError {
		err.sqlstate
	} else if err.code() == 0 {
		'HY000'
	} else {
		vsql.sqlstate_from_int(err.code())
	}
	d.records << DiagnosticRecord{sqlstate, err.msg()}

	return sql_error
}

// result is the return code after a routine succeeds, which may have raised
// warnings.
fn (d Diagnostics) result() i16 {
	return if d.records.len > 0 { sql_success_with_info } else { sql_success }
}
