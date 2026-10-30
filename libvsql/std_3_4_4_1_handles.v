module main

import sync
import vsql

// ISO/IEC 9075-3:2003(E), 4.4.1, Handles
//
// A handle is an integer that identifies an allocated SQL-environment,
// SQL-connection, SQL-statement or CLI descriptor area. Handles are never
// reused, so a freed handle stays invalid.

const sql_handle_env = i16(1)
const sql_handle_dbc = i16(2)
const sql_handle_stmt = i16(3)
const sql_handle_desc = i16(4)
const sql_null_handle = 0

// The allocated resources. These maps also keep the resources reachable for
// the GC, since the C program only has their handles.
__global envs = map[i64]&Env{}
__global dbcs = map[i64]&Dbc{}
__global stmts = map[i64]&Stmt{}
__global last_handle = i64(0)

// An allocated SQL-environment.
struct Env {
mut:
	diag Diagnostics
	// null_termination is the NULL TERMINATION attribute (see 4.4.2, "Null
	// terminated strings").
	null_termination bool = true
	// data_source is the next data source for DataSources.
	data_source int
	// current_connection is the handle of the current SQL-connection, or 0 if
	// there isn't one (see 5.3, "Implicit set connection").
	current_connection i64
	// mutex is locked while a routine is invoked with a handle of this
	// SQL-environment (see threads.v).
	mutex &sync.Mutex = sync.new_mutex()
}

// An allocated SQL-connection. conn is the established SQL-connection, if any.
struct Dbc {
	handle i64
mut:
	diag Diagnostics
	env  i64
	conn ?&vsql.Connection
	// is_default is true when the connection was made to the 'DEFAULT' server.
	is_default bool
	// server_name is the ServerName of the last Connect, or 'DEFAULT'.
	server_name string
	// savepoint_name is the SAVEPOINT NAME attribute.
	savepoint_name string
	// autocommit is the AUTOCOMMIT attribute, and autocommit_transaction is
	// true if the active SQL-transaction was started by a statement while it
	// was on (see autocommit.v).
	autocommit             bool
	autocommit_transaction bool
}

// An allocated SQL-statement.
struct Stmt {
	handle i64
mut:
	diag Diagnostics
	dbc  i64
	// executed is true once a statement has been executed, even if it didn't
	// return a cursor.
	executed bool
	// row_count is the number of rows affected by the executed statement (see
	// RowCount).
	row_count int
	// cursor is the open cursor, if any, and rows are its rows. The cursor is
	// positioned on the rowset of rowset_len rows from rowset_start, which is
	// -1 before the first row, and rows.len after the last row.
	cursor       ?vsql.Result
	rows         []vsql.Row
	rowset_start int = -1
	rowset_len   int
	// fetched is true once the cursor has been positioned on a rowset (which
	// is empty after the last row) by Fetch or FetchScroll.
	fetched bool
	// fetched_column is the fetched column number, which is negative while a
	// character value is being retrieved in pieces by GetData. fetched_length
	// is the number of octets of fetched_value already retrieved.
	fetched_column int
	fetched_length int
	fetched_value  string
	// cursor_name is the name of the cursor, or empty if it doesn't have one
	// yet (see cursor_name). is_query is true if the executed statement opened
	// a cursor (which may be closed now).
	cursor_name string
	is_query    bool
	// dynamic_cursor is the name of the cursor of the connection (see
	// PreparedStmt.open_cursor) while a query's cursor is open, so a positioned
	// DELETE or UPDATE of another statement can change its current row.
	dynamic_cursor string
	// prepared is the statement prepared by Prepare, if any, and the
	// DYNAMIC_FUNCTION and DYNAMIC_FUNCTION_CODE that identify it.
	prepared               ?&vsql.PreparedStmt
	prepared_function      string
	prepared_function_code int
	// While a statement is waiting for the values of its deferred parameters
	// (see ParamData and PutData), deferred_parameters are the numbers of the
	// parameters that are still deferred (the first one is the deferred
	// parameter number), deferred_params are the values of the other
	// parameters, and deferred_stmt is the statement. deferred_data_pointer is
	// true once ParamData has returned the DATA_POINTER of the deferred
	// parameter, and deferred_value is the value given by PutData so far.
	deferred_parameters   []int
	deferred_params       map[string]vsql.Value
	deferred_stmt         ?&vsql.PreparedStmt
	deferred_data_pointer bool
	deferred_value        ?vsql.Value
	// ard and apd are the current ARD and APD, which are the automatically
	// allocated auto_ard and auto_apd unless the application set them to a
	// descriptor that it allocated.
	ard      i64
	apd      i64
	ird      i64
	ipd      i64
	auto_ard i64
	auto_apd i64
	// The statement attributes, see Table 17, "Codes used for statement
	// attributes".
	cursor_scrollable   i64 = sql_nonscrollable
	cursor_sensitivity  i64 = sql_asensitive
	cursor_holdable     i64 = sql_holdable
	metadata_id         i64 = sql_false
	nest_descriptor     i64 = sql_false
	current_of_position i64 = 1
}

// new_stmt allocates an SQL-statement for a connection, with its automatically
// allocated descriptors (see 6.3, "AllocHandle", General Rule 3.c.x).
fn new_stmt(dbc i64) i64 {
	h := new_handle()
	ard := new_desc(dbc, .ard, h)
	apd := new_desc(dbc, .apd, h)
	stmts[h] = &Stmt{
		handle:   h
		dbc:      dbc
		ard:      ard
		apd:      apd
		ird:      new_desc(dbc, .ird, h)
		ipd:      new_desc(dbc, .ipd, h)
		auto_ard: ard
		auto_apd: apd
	}

	return h
}

// free_stmt frees an SQL-statement and its automatically allocated
// descriptors.
fn free_stmt(h i64) {
	stmt := stmts[h] or { return }
	for dh in [stmt.auto_ard, stmt.auto_apd, stmt.ird, stmt.ipd] {
		descs.delete(dh)
	}
	stmts.delete(h)
}

fn new_handle() i64 {
	last_handle++
	return last_handle
}

fn (mut stmt Stmt) close_cursor() {
	if stmt.dynamic_cursor != '' {
		if mut conn := stmt_connection(stmt) {
			conn.remove_cursor(stmt.dynamic_cursor)
		}
		stmt.dynamic_cursor = ''
	}
	stmt.cursor = none
	stmt.rows = []
	stmt.rowset_start = -1
	stmt.rowset_len = 0
	stmt.fetched = false
	stmt.fetched_column = 0
}

// open_cursor opens a cursor on the result of a query, positioned before the
// first row.
fn (mut stmt Stmt) open_cursor(result vsql.Result) {
	mut r := result
	mut rows := []vsql.Row{}
	for row in r {
		rows << row
	}
	stmt.close_cursor()
	stmt.cursor = result
	stmt.rows = rows
}

// position_cursor positions the cursor of the connection on the row of the
// rowset at the CURRENT OF POSITION (or on no row if there isn't one), which is
// the current row of a positioned DELETE or UPDATE (see 4.4.6, "Statement
// attributes").
fn (mut stmt Stmt) position_cursor() {
	if stmt.dynamic_cursor == '' {
		return
	}

	mut row := -1
	if stmt.current_of_position <= stmt.rowset_len {
		row = stmt.rowset_start + int(stmt.current_of_position) - 1
	}

	// The cursor of the connection is closed if the transaction was rolled
	// back, so a positioned DELETE or UPDATE would be an invalid cursor state.
	if mut conn := stmt_connection(stmt) {
		conn.position_cursor(stmt.dynamic_cursor, row) or {}
	}
}

// handle_env is the SQL-environment of a handle, or zero if the handle isn't
// allocated.
fn handle_env(handle_type i16, h i64) i64 {
	return match handle_type {
		sql_handle_env { h }
		sql_handle_dbc { (dbcs[h] or { return 0 }).env }
		sql_handle_stmt { (dbcs[(stmts[h] or { return 0 }).dbc] or { return 0 }).env }
		sql_handle_desc { (dbcs[(descs[h] or { return 0 }).dbc] or { return 0 }).env }
		else { 0 }
	}
}

// null_termination is the NULL TERMINATION attribute of an SQL-environment.
fn null_termination(env i64) bool {
	return (envs[env] or { return true }).null_termination
}

fn (stmt &Stmt) null_termination() bool {
	return null_termination((dbcs[stmt.dbc] or { return true }).env)
}

// deferred is the deferred parameter number, or 0 (zero) if there isn't one.
fn (stmt &Stmt) deferred() int {
	return if stmt.deferred_parameters.len > 0 { stmt.deferred_parameters[0] } else { 0 }
}

// cancel_deferred removes the deferred parameter number and the statement that
// was waiting for it.
fn (mut stmt Stmt) cancel_deferred() {
	stmt.deferred_parameters = []
	stmt.deferred_params = map[string]vsql.Value{}
	stmt.deferred_stmt = none
	stmt.deferred_data_pointer = false
	stmt.deferred_value = none
}

// check_deferred raises an exception condition if the statement is waiting
// for the values of its deferred parameters: CLI-specific condition —
// function sequence error (see 5.2, "<CLI routine> invocation", General Rule
// 3.b.i.6).
fn (stmt &Stmt) check_deferred() ! {
	if stmt.deferred() > 0 {
		return cli_error('HY010', 'function sequence error')
	}
}

// get_cursor_name is the name of the cursor of a statement. A statement that
// doesn't have one gets a unique name that starts with "SQL_CUR".
fn (mut stmt Stmt) get_cursor_name() string {
	if stmt.cursor_name == '' {
		stmt.cursor_name = 'SQL_CUR${stmt.handle}'
	}

	return stmt.cursor_name
}
