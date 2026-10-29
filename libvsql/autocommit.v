module main

// AUTOCOMMIT is an implementation-defined connection attribute (it has the
// same code and values as in ODBC). The standard doesn't have it: the first
// statement starts an SQL-transaction, which lasts until EndTran. When
// AUTOCOMMIT is on, an SQL-transaction that a statement started is committed
// once the statement has finished and no cursor of the connection is open (so
// a query is committed when its cursor is closed). One that's started by
// StartTran isn't, so it lasts until EndTran.

const sql_attr_autocommit = 102
const sql_autocommit_off = 0
const sql_autocommit_on = 1

// autocommit ends the SQL-transaction of a connection if it was started by a
// statement while AUTOCOMMIT was on, and no cursor of the connection is open.
fn autocommit(mut diag Diagnostics, dh i64, is_commit bool) ! {
	mut dbc := dbcs[dh] or { return }
	mut conn := dbc.conn or { return }
	if !dbc.autocommit_transaction || !conn.in_transaction() {
		return
	}
	for _, stmt in stmts {
		if stmt.dbc == dh && stmt.cursor != none {
			return
		}
	}

	dbc.autocommit_transaction = false
	end_transaction(mut diag, mut conn, is_commit)!
}

// set_autocommit sets the AUTOCOMMIT attribute. Turning it on commits the
// SQL-transaction, if there is one, the same as in ODBC.
fn set_autocommit(mut dbc Dbc, h i64, value voidptr) ! {
	v := read_integer(value)!
	if v !in [sql_autocommit_off, sql_autocommit_on] {
		return cli_error('HY024', 'invalid attribute value')
	}

	on := v == sql_autocommit_on
	if on && !dbc.autocommit {
		if mut conn := dbc.conn {
			if conn.in_transaction() {
				close_cursors(h, true)
				end_transaction(mut dbc.diag, mut conn, true)!
			}
		}
	}
	dbc.autocommit = on
	dbc.autocommit_transaction = false
}
