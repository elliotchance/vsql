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
mut:
	// column_number is the column that the condition applies to, or 0 (zero)
	// if it doesn't apply to a column.
	column_number int
}

// Diagnostics is a diagnostics area. The header fields describe the last
// routine (other than Error, GetDiagField and GetDiagRec) that was called with
// the handle, see Table 1, "Fields in SQL/CLI diagnostics areas".
struct Diagnostics {
mut:
	records []DiagnosticRecord
	// processed is the number of status records already returned by Error.
	processed int
	// returncode is the return code of the routine.
	returncode i16
	// is_execute is true when the routine is ExecDirect, and row_count is the
	// number of rows affected by the statement that it executed.
	is_execute bool
	row_count  int
	// dynamic_function and dynamic_function_code identify the statement that
	// was executed (see Table 31, "SQL-statement codes", in ISO/IEC 9075-2),
	// or are empty if no statement was executed.
	dynamic_function      string
	dynamic_function_code int
	// transactions_committed and transactions_rolled_back are the number of
	// SQL-transactions that the routine committed or rolled back.
	transactions_committed   int
	transactions_rolled_back int
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
	d.processed = 0
	d.returncode = sql_success
	d.is_execute = false
	d.row_count = 0
	d.dynamic_function = ''
	d.dynamic_function_code = 0
	d.transactions_committed = 0
	d.transactions_rolled_back = 0
}

// warning raises a completion condition, such as "01004 string data, right
// truncation".
fn (mut d Diagnostics) warning(sqlstate string, msg string) i16 {
	d.records << DiagnosticRecord{
		sqlstate: sqlstate
		msg:      msg
	}
	if d.returncode == sql_success {
		d.returncode = sql_success_with_info
	}

	return sql_success_with_info
}

// no_data raises a completion condition: no data. There isn't a status record
// for it.
fn (mut d Diagnostics) no_data() i16 {
	d.returncode = sql_no_data

	return sql_no_data
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
	d.records << DiagnosticRecord{
		sqlstate: sqlstate
		msg:      err.msg()
	}
	d.returncode = sql_error

	return sql_error
}

// result is the return code after a routine succeeds, which may have raised
// warnings.
fn (d Diagnostics) result() i16 {
	return if d.records.len > 0 { sql_success_with_info } else { sql_success }
}

// handle_diagnostics returns the diagnostics area of the resource identified by
// a handle of the handle type, or none if it's not an allocated resource of
// that type.
fn handle_diagnostics(handle_type i16, h i64) ?&Diagnostics {
	match handle_type {
		sql_handle_env {
			mut env := envs[h] or { return none }
			return &env.diag
		}
		sql_handle_dbc {
			mut dbc := dbcs[h] or { return none }
			return &dbc.diag
		}
		sql_handle_stmt {
			mut stmt := stmts[h] or { return none }
			return &stmt.diag
		}
		else {
			return none
		}
	}
}

// end_transaction counts an SQL-transaction that was active before a statement
// was executed, and isn't any more, as committed (by a successful COMMIT) or
// rolled back (by a ROLLBACK, or an error).
fn (mut d Diagnostics) end_transaction(was_active bool, is_active bool, ok bool) {
	if was_active && !is_active {
		if ok && d.dynamic_function == 'COMMIT WORK' {
			d.transactions_committed++
		} else {
			d.transactions_rolled_back++
		}
	}
}
