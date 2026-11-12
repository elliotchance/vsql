module main

import vsql

// ISO/IEC 9075-3:2003(E), 4.3, Diagnostics areas in SQL/CLI
//
// Each handle has a diagnostics area that is emptied at the start of each CLI
// routine (other than Error, GetDiagField and GetDiagRec) that's given the
// handle. The conditions are read with GetDiagRec. The status records are kept
// ordered by ROW_NUMBER, then by precedence, then in the order that they're
// raised (see DiagnosticRecord.position). There's no status record for a
// completion condition: no data (see no_data).
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.8.4, Diagnostic
// information.

struct DiagnosticRecord {
	sqlstate string
	msg      string
	// constraint is the constraint that was violated, for an integrity
	// constraint violation (see vsql.violated_constraint).
	constraint vsql.Identifier
	// table is the table (and, as its sub_entity_name, the column) that the
	// condition identifies (see vsql.condition_table).
	table vsql.Identifier
	// cursor_name is the cursor that caused a warning: cursor operation conflict.
	cursor_name string
	// cursor is the name of the cursor (as the engine keeps it) that is in the
	// invalid state, for an invalid cursor state raised by the engine (see
	// vsql.invalid_cursor).
	cursor string
mut:
	// row_number and column_number are the row of the rowset and the column
	// that the condition applies to, or 0 (zero) if it doesn't apply to one
	// (see 4.3.1, "Setting of ROW_NUMBER and COLUMN_NUMBER fields").
	row_number    int
	column_number int
}

// position is where the status record sorts in a diagnostics area: by
// ROW_NUMBER, and within a ROW_NUMBER, transaction rollback has precedence over
// other exceptions, then no data, then warnings. The standard only needs this of
// the first status record of a ROW_NUMBER, the others are
// implementation-dependent.
fn (r DiagnosticRecord) position() i64 {
	precedence := match r.sqlstate[..2] {
		'40' { 0 }
		'02' { 2 }
		'01' { 3 }
		else { 1 }
	}

	return i64(r.row_number) * 4 + precedence
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
	// more is true if the routine raised more conditions than are in records.
	more bool
}

// CLIError is an exception condition raised by a CLI routine itself, rather
// than one from executing an SQL statement. Its SQLSTATE is from Table 4 (in
// ISO/IEC 9075-3:2003(E), 5.12, CLI-specific status codes), or HY000 when the
// condition doesn't have a subclass.
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
	d.more = false
}

// add inserts a status record after the records that sort before or with it, so
// that conditions of the same position stay in the order they were raised.
fn (mut d Diagnostics) add(record DiagnosticRecord) {
	mut i := d.records.len
	for i > 0 && d.records[i - 1].position() > record.position() {
		i--
	}
	d.records.insert(i, record)
}

// warning raises a completion condition, such as "01004 string data, right
// truncation".
fn (mut d Diagnostics) warning(sqlstate string, msg string) i16 {
	d.add(DiagnosticRecord{
		sqlstate: sqlstate
		msg:      msg
	})
	if d.returncode == sql_success {
		d.returncode = sql_success_with_info
	}

	return sql_success_with_info
}

// statement_warnings raises the warnings of the statement that the connection
// just executed. If the statement failed, then the exception condition also
// needs a condition area. A completion condition: no data (such as a DELETE,
// INSERT or UPDATE of no rows) doesn't have a status record, but it's the
// return code of a statement that succeeded (see no_data), even if there were
// warnings too.
//
// ISO/IEC 9075-2:2016(E), 4.36, Diagnostics area
// ISO/IEC 9075-3:2003(E), 4.1, Introduction to SQL/CLI
// ISO/IEC 9075-3:2003(E), 5.2, <CLI routine> invocation, General Rules, 5.b.ii
fn (mut d Diagnostics) statement_warnings(conn &vsql.Connection, failed bool) {
	d.more = conn.more_conditions
	if !failed && conn.warnings.any(vsql.sqlstate_from_int(it.code()).starts_with('02')) {
		d.no_data()
	}
	mut warnings := conn.warnings.filter(!vsql.sqlstate_from_int(it.code()).starts_with('02'))
	limit := if failed { conn.condition_area_limit - 1 } else { conn.condition_area_limit }
	if warnings.len > limit {
		warnings = warnings[warnings.len - limit..].clone()
		d.more = true
	}
	for warning in warnings {
		// A warning: cursor operation conflict has the name of the cursor that
		// caused it (a DELETE or UPDATE can raise it).
		d.add(DiagnosticRecord{
			sqlstate:    vsql.sqlstate_from_int(warning.code())
			msg:         warning.msg()
			cursor_name: vsql.conflicting_cursor(warning) or { '' }
		})
		if d.returncode == sql_success {
			d.returncode = sql_success_with_info
		}
	}
}

// row_condition records a condition raised for a column of a row of a rowset
// by Fetch or FetchScroll, without changing the return code.
fn (mut d Diagnostics) row_condition(err IError, row_number int, column_number int) {
	sqlstate := if err is CLIError {
		err.sqlstate
	} else if err.code() == 0 {
		'HY000'
	} else {
		vsql.sqlstate_from_int(err.code())
	}
	d.add(DiagnosticRecord{
		sqlstate:      sqlstate
		msg:           err.msg()
		constraint:    vsql.violated_constraint(err) or { vsql.Identifier{} }
		table:         vsql.condition_table(err) or { vsql.Identifier{} }
		row_number:    row_number
		column_number: column_number
	})
}

// no_data raises a completion condition: no data. There isn't a status record
// for it.
fn (mut d Diagnostics) no_data() i16 {
	d.returncode = sql_no_data

	return sql_no_data
}

// NoData is returned (as an error) by a function that raises a completion
// condition: no data.
struct NoData {
	Error
}

fn no_data() IError {
	return NoData{}
}

// error raises an exception condition. err is either a CLIError or an error
// from vsql (which has the SQLSTATE as its code). A NoData isn't an exception
// condition, see no_data.
fn (mut d Diagnostics) error(err IError) i16 {
	if err is NoData {
		return d.no_data()
	}

	mut sqlstate := if err is CLIError {
		err.sqlstate
	} else if err.code() == 0 {
		'HY000'
	} else {
		vsql.sqlstate_from_int(err.code())
	}
	mut msg := err.msg()

	// A statement can only be canceled by Cancel, which raises a CLI-specific
	// condition: operation canceled for the routine that was executing it.
	//
	// ISO/IEC 9075-3:2003(E), 6.7, Cancel, General Rules, 2.a.vii
	if sqlstate == '57014' {
		sqlstate = 'HY008'
		msg = 'operation canceled'
	}
	d.add(DiagnosticRecord{
		sqlstate:   sqlstate
		msg:        msg
		constraint: vsql.violated_constraint(err) or { vsql.Identifier{} }
		table:      vsql.condition_table(err) or { vsql.Identifier{} }
		cursor:     vsql.invalid_cursor(err) or { '' }
	})
	d.returncode = sql_error

	return sql_error
}

// result is the return code after a routine succeeds, which may have raised
// warnings or no data (which comes later in the list of return codes, so it's
// returned instead of a warning).
fn (d Diagnostics) result() i16 {
	if d.returncode == sql_no_data {
		return sql_no_data
	}

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
		sql_handle_desc {
			mut desc := descs[h] or { return none }
			return &desc.diag
		}
		else {
			return none
		}
	}
}
