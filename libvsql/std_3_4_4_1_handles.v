module main

import vsql

// ISO/IEC 9075-3:2003(E), 4.4.1, Handles
//
// A handle is an integer that identifies an allocated SQL-environment,
// SQL-connection or SQL-statement. Handles are never reused, so a freed handle
// stays invalid.

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
	// cursor is the open cursor, if any.
	cursor ?vsql.Result
	// fetched is true after the first Fetch on the cursor and row is the
	// fetched row (none after the last row).
	fetched bool
	row     ?vsql.Row
	// fetched_column is the fetched column number, which is negative while a
	// character value is being retrieved in pieces by GetData. fetched_length
	// is the number of octets of fetched_value already retrieved.
	fetched_column int
	fetched_length int
	fetched_value  string
}

fn new_handle() i64 {
	last_handle++
	return last_handle
}

fn (mut stmt Stmt) close_cursor() {
	stmt.cursor = none
	stmt.fetched = false
	stmt.row = none
	stmt.fetched_column = 0
}
