module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.61, StartTran
//
// Explicitly start an SQL-transaction and set its characteristics.
//
// READ WRITE with READ UNCOMMITTED is 42601, as it is for START TRANSACTION
// (ISO/IEC 9075-2:2023(E), 17.3, Syntax Rules, 4).
//
// For an SQL-environment, L1 is only its active SQL-connections (General Rules,
// 3.d.ii.3), which are the ones that have executed a statement in the current
// SQL-transaction (ISO/IEC 9075-2:2023(E), 4.44, SQL-connections). Any of those
// has an active SQL-transaction, which is an exception condition (General
// Rules, 4), so TXN is started without being in any SQL-connection yet
// (General Rules, 10). It's started in the first connection that executes a
// statement (see run_statement), and switching to another connection after
// that is 0A001 like any other SQL-transaction (see 5.3, "Implicit set
// connection"). Until then, any of its connections can be used, and it's the
// active SQL-transaction of the SQL-environment (4.1, Introduction to SQL/CLI),
// so a statement doesn't initiate another one.
//
// Because none of the connections is active, L1 is also empty for a later
// StartTran, whether it's given the SQL-environment or one of its connections
// (General Rules, 3.c.ii.4), so General Rules 4 doesn't raise an exception, and
// TXN is a new SQL-transaction (General Rules, 7). An SQL-agent has one current
// SQL-transaction, so TXN replaces the one that hasn't been started in any
// connection, which has had no effects.
//
// For a connection, TXN is started in its SQL-connection straight away, since
// that's the only one it can be in.
//
// StartTran doesn't have a DIAGNOSTICS SIZE, so a SET TRANSACTION before it
// still sets the DIAGNOSTICS SIZE of TXN (but not its access mode or isolation
// level). That's how a <start transaction statement> in an SQL-client module is
// done, since it effectively executes a SET TRANSACTION first (ISO/IEC
// 9075-2:2023(E), 17.1, <start transaction statement>, General Rules, 4).

// Codes from Table 36, "Values for TRANSACTION ACCESS MODE with StartTran".
const sql_transaction_read_only = 0x00000001
const sql_transaction_read_write = 0x00000002

// Codes from Table 35, "Values for TRANSACTION ISOLATION OPTION with GetInfo
// and StartTran".
const sql_transaction_read_uncommitted = 0x00000001
const sql_transaction_read_committed = 0x00000002
const sql_transaction_repeatable_read = 0x00000004
const sql_transaction_serializable = 0x00000008

@[export: 'SQLStartTran']
fn sql_start_tran(handle_type i16, handle SQLInteger, access_mode SQLInteger, isolation_level SQLInteger) i16 {
	entry := enter(handle_type, i64(handle))
	defer {
		entry.leave()
	}
	h := i64(handle)
	mut diag, l1 := transaction_handles(handle_type, h) or { return sql_invalid_handle }
	diag.clear()

	return start_tran(handle_type, h, l1, i64(access_mode), i64(isolation_level)) or {
		diag.error(err)
	}
}

fn start_tran(handle_type i16, h i64, l1 []i64, access_mode i64, isolation_level i64) !i16 {
	// - 3.a.ii, 3.b.ii. A statement or descriptor handle raises an exception
	// condition: CLI-specific condition — invalid attribute identifier.
	if handle_type in [sql_handle_stmt, sql_handle_desc] {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	// - 3.c.ii.3. If there is no established SQL-connection associated with C,
	// then an exception condition is raised: connection exception —
	// connection does not exist.
	if handle_type == sql_handle_dbc && l1.len == 0 {
		return cli_error('08003', 'connection does not exist')
	}

	// - 4. If an SQL-transaction is currently active on any of the
	// SQL-connections contained in L1, then an exception condition is raised:
	// invalid transaction state — active SQL-transaction.
	for dh in l1 {
		if connection_active(dh) {
			return cli_error('25001', 'active SQL-transaction')
		}
	}

	// - 5, 6. AM and IL must be one of the codes in Table 36 and Table 35,
	// otherwise an exception condition is raised: CLI-specific condition —
	// invalid attribute identifier.
	if access_mode !in [i64(sql_transaction_read_only), sql_transaction_read_write]
		|| isolation_level !in [i64(sql_transaction_read_uncommitted), sql_transaction_read_committed,
			sql_transaction_repeatable_read, sql_transaction_serializable] {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	// - 8, 9. The access mode and isolation level of TXN are set.
	access := if access_mode == sql_transaction_read_only { 'READ ONLY' } else { 'READ WRITE' }
	level := match isolation_level {
		i64(sql_transaction_read_uncommitted) { 'READ UNCOMMITTED' }
		i64(sql_transaction_read_committed) { 'READ COMMITTED' }
		i64(sql_transaction_repeatable_read) { 'REPEATABLE READ' }
		else { 'SERIALIZABLE' }
	}

	// - 10. TXN is started in each SQL-connection contained in L1. For an
	// SQL-environment there aren't any, so it's started in the first
	// connection that executes a statement. Either way, it replaces an
	// SQL-transaction that StartTran started for the SQL-environment that
	// hasn't been started in a connection yet.
	mut e := envs[handle_env(handle_type, h)] or { return sql_invalid_handle }
	if handle_type == sql_handle_env {
		e.start_tran = '${access}, ISOLATION LEVEL ${level}'
		return sql_success
	}
	mut dbc := dbcs[h] or { return sql_invalid_handle }
	mut conn := dbc.conn or { return cli_error('08003', 'connection does not exist') }
	implicit_set_connection(h)!
	db_query(mut conn, 'START TRANSACTION ${access}, ISOLATION LEVEL ${level}${diagnostics_size(conn)}')!
	e.start_tran = ''
	dbc.autocommit_transaction = false

	return sql_success
}

// start_tran_pending is true if StartTran started an SQL-transaction for an
// SQL-environment that hasn't been started in any of its connections yet.
fn start_tran_pending(env i64) bool {
	return (envs[env] or { return false }).start_tran != ''
}

// join_start_tran starts the SQL-transaction that StartTran started for the
// SQL-environment of a connection in that connection (General Rules, 10),
// when it doesn't have an active SQL-transaction.
fn join_start_tran(mut conn vsql.Connection, dh i64) ! {
	mut dbc := dbcs[dh] or { return }
	mut e := envs[dbc.env] or { return }
	if e.start_tran == '' || conn.in_transaction() {
		return
	}

	db_query(mut conn, 'START TRANSACTION ${e.start_tran}${diagnostics_size(conn)}')!
	e.start_tran = ''
	dbc.autocommit_transaction = false
}

// diagnostics_size is the DIAGNOSTICS SIZE that a SET TRANSACTION before
// StartTran set for the next SQL-transaction of a connection, if there was one.
fn diagnostics_size(conn vsql.Connection) string {
	size := conn.next_diagnostics_size()
	return if size > 0 { ', DIAGNOSTICS SIZE ${size}' } else { '' }
}
