module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.17, EndTran
//
// Terminate an SQL-transaction.
//
// Each SQL-connection has its own SQL-transaction, so ending the transactions
// of an SQL-environment ends the SQL-transaction of each of its connections.

// Codes from Table 14, "Codes used for transaction termination".
const sql_commit = i16(0)
const sql_rollback = i16(1)
const sql_savepoint_name_rollback = i16(2)
const sql_savepoint_name_release = i16(4)
const sql_commit_and_chain = i16(6)
const sql_rollback_and_chain = i16(7)

@[export: 'SQLEndTran']
fn sql_end_tran(handle_type i16, handle SQLInteger, completion_type i16) i16 {
	h := i64(handle)

	// - 3. A statement or descriptor can't be used, and the connections are
	// the established SQL-connection of a connection, or all of them for an
	// SQL-environment.
	mut diag, l1 := transaction_handles(handle_type, h) or { return sql_invalid_handle }
	diag.clear()

	return end_tran(mut diag, handle_type, l1, completion_type) or { diag.error(err) }
}

fn end_tran(mut diag Diagnostics, handle_type i16, l1 []i64, completion_type i16) !i16 {
	if handle_type in [sql_handle_stmt, sql_handle_desc] {
		return cli_error('HY092', 'invalid attribute identifier')
	}

	// - 5. If CT is not one of the code values in Table 14, then an exception
	// condition is raised: CLI-specific condition — invalid transaction
	// operation code.
	if completion_type !in [sql_commit, sql_rollback, sql_savepoint_name_rollback,
		sql_savepoint_name_release, sql_commit_and_chain, sql_rollback_and_chain] {
		return cli_error('HY012', 'invalid transaction operation code')
	}

	// - 6. If L1 is empty, then no further rules of this Subclause are applied.
	if l1.len == 0 {
		return sql_success
	}

	// - 13, 15. SAVEPOINT NAME RELEASE and SAVEPOINT NAME ROLLBACK can only be
	// used with a connection, and the SAVEPOINT NAME must be a savepoint of the
	// current SQL-transaction. vsql doesn't support savepoints, so there never
	// is one.
	if completion_type in [sql_savepoint_name_rollback, sql_savepoint_name_release] {
		if handle_type != sql_handle_dbc {
			return sql_invalid_handle
		}
		return cli_error('3B001', 'savepoint exception — invalid specification')
	}

	is_commit := completion_type in [sql_commit, sql_commit_and_chain]
	is_chain := completion_type in [sql_commit_and_chain, sql_rollback_and_chain]
	mut errors := []IError{}
	for dh in l1 {
		mut dbc := dbcs[dh] or { continue }
		mut conn := dbc.conn or { continue }

		// - 11. A rollback closes every open cursor, and a commit closes every
		// cursor that isn't holdable.
		close_cursors(dh, is_commit)

		if !conn.in_transaction() {
			continue
		}

		// - 12, 14. The current SQL-transaction is terminated. If CT indicates
		// COMMIT AND CHAIN or ROLLBACK AND CHAIN, then a new SQL-transaction is
		// initiated.
		end_transaction(mut diag, mut conn, is_commit) or {
			errors << err
			continue
		}
		if is_chain {
			conn.query('START TRANSACTION') or { errors << err }
		}
	}

	if errors.len > 0 {
		for err in errors[..errors.len - 1] {
			diag.error(err)
		}
		return errors.last()
	}

	return sql_success
}

// end_transaction commits or rolls back the SQL-transaction of an established
// connection. A commit that fails rolls back the SQL-transaction instead.
fn end_transaction(mut diag Diagnostics, mut conn vsql.Connection, is_commit bool) ! {
	conn.query(if is_commit { 'COMMIT' } else { 'ROLLBACK' }) or {
		if !conn.in_transaction() {
			diag.transactions_rolled_back++
		}
		return err
	}

	if is_commit {
		diag.transactions_committed++
	} else {
		diag.transactions_rolled_back++
	}
}

// transaction_handles returns the diagnostics area of the handle that EndTran
// or StartTran was given, and its allocated SQL-connections that have an
// established SQL-connection, or none if it isn't an allocated handle.
fn transaction_handles(handle_type i16, h i64) ?(&Diagnostics, []i64) {
	mut diag := handle_diagnostics(handle_type, h)?
	mut l1 := []i64{}
	for dh, dbc in dbcs {
		if dbc.conn != none && ((handle_type == sql_handle_dbc && dh == h)
			|| (handle_type == sql_handle_env && dbc.env == h)) {
			l1 << dh
		}
	}
	l1.sort()

	return diag, l1
}

// close_cursors closes the open cursor of every statement of a connection, or
// only the cursors that aren't holdable for a commit.
fn close_cursors(dbc i64, is_commit bool) {
	for _, mut stmt in stmts {
		if stmt.dbc == dbc && !(is_commit && stmt.cursor_holdable == sql_holdable) {
			stmt.close_cursor()
		}
	}
}
