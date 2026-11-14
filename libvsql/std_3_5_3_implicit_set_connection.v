module main

import vsql

// ISO/IEC 9075-3:2003, 5.3, Implicit set connection
//
// Specify the rules for an implicit SET CONNECTION statement.
//
// Each SQL-connection is to a different SQL-server (a database file, or a new
// in-memory database). An SQL-transaction can affect more than one SQL-server
// (ISO/IEC 9075-2:2023, Feature T262): the part of it on each SQL-connection is
// a branch, which is started with the same characteristics, unless SET LOCAL
// TRANSACTION changes them (see set_branch). EndTran with any of the
// connections ends every branch (see end_tran).

// Each SQL-environment is its own SQL-agent, with its own current
// SQL-connection (Env.current_connection), so connections that are allocated in
// different SQL-environments can each have an active SQL-transaction, and can be
// used from different threads at the same time.

// current_connection is the handle of the current SQL-connection of an
// SQL-environment, or 0 if there isn't one.
fn current_connection(env i64) i64 {
	return (envs[env] or { return 0 }).current_connection
}

fn set_current_connection(env i64, dc i64) {
	mut e := envs[env] or { return }
	e.current_connection = dc
}

fn implicit_set_connection(dc i64) ! {
	env := (dbcs[dc] or { return }).env
	current := current_connection(env)
	if dc == current {
		return
	}

	// ISO/IEC 9075-3:2003, 5.3, Implicit set connection, General Rules, 2:
	// the current SQL-connection can have an active SQL-transaction, since
	// vsql supports transactions over more than one SQL-server.

	// ISO/IEC 9075-3:2003, 5.3, Implicit set connection, General Rules, 4-6:
	// the current SQL-connection becomes dormant, and DC becomes the current
	// SQL-connection. Each connection keeps its own SQL-session (and server).
	// Selecting a connection can't fail (General Rules, 3).
	set_current_connection(env, dc)
}

// active_branches are the connections of the SQL-environment of dh, other than
// dh, that have an active branch of its SQL-transaction, by handle.
fn active_branches(dh i64) []i64 {
	env := (dbcs[dh] or { return [] }).env
	mut l := []i64{}
	for h, dbc in dbcs {
		if h != dh && dbc.env == env && connection_active(h) {
			l << h
		}
	}
	l.sort()

	return l
}

// set_branch makes the next SQL-transaction of the connection dh a branch of
// the SQL-transaction of its SQL-environment, when that's active on another
// connection, otherwise it stops it being one (see vsql.Connection.set_branch_of).
//
// ISO/IEC 9075-2:2023, 4.43.7.2, Encompassing transaction belonging to the SQL-agent
fn set_branch(mut conn vsql.Connection, dh i64) {
	for h in active_branches(dh) {
		if other := (dbcs[h] or { continue }).conn {
			conn.set_branch_of(other)
			return
		}
	}
	conn.set_branch_of(conn)
}
