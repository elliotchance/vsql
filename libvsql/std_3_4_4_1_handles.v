module main

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
}

// An allocated SQL-connection. conn is the established SQL-connection, if any.
struct Dbc {
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
}

// An allocated SQL-statement.
struct Stmt {
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
