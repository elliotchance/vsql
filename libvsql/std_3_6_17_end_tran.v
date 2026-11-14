module main

import vsql

// ISO/IEC 9075-3:2003, 6.17, EndTran
//
// Terminate an SQL-transaction.
//
// Each SQL-connection has its own branch of the SQL-transaction of its
// SQL-environment (ISO/IEC 9075-2:2023, Feature T262), so ending the
// transactions of an SQL-environment ends the branch of each of its
// connections. L1 is every established SQL-connection, and a connection that
// doesn't have an active SQL-transaction only has its cursors closed (General
// Rules 3.c.ii.3 and 3.d.ii.3). Ending the transaction of a connection ends the
// SQL-transaction, so L1 also has the other connections of its
// SQL-environment that have an active branch.
//
// Before a commit of more than one branch, the deferred constraints of each are
// checked, so that if any of them aren't satisfied, every branch is rolled
// back. Committing more than one SQL-server isn't atomic, though: if committing
// one of them fails after that (which can only be because of the SQL-server,
// such as a disk error), the ones before it stay committed.
//
// A COMMIT or ROLLBACK is executed on each connection, so its General Rules
// apply: deferred constraints are checked, and if any constraint (or anything
// else) prevents the commit, the SQL-transaction is rolled back (General Rules
// 12.c and 12.d). There's no encompassing transaction, atomic execution
// context, temporary table, trigger or locator (General Rules 7, 12.a, 12.b,
// 12.d.ii, 12.f, 14.a, 14.d, 15.d and 15.g). COMMIT and ROLLBACK destroy every
// savepoint (General Rules 12.e and 14.c).

// Codes from Table 14, "Codes used for transaction termination".
const sql_commit = i16(0)
const sql_rollback = i16(1)
const sql_savepoint_name_rollback = i16(2)
const sql_savepoint_name_release = i16(4)
const sql_commit_and_chain = i16(6)
const sql_rollback_and_chain = i16(7)

@[export: 'SQLEndTran']
fn sql_end_tran(handle_type i16, handle SQLInteger, completion_type i16) i16 {
	entry := enter(handle_type, i64(handle))
	defer {
		entry.leave()
	}
	h := i64(handle)

	// - 3. A statement or descriptor can't be used, and the connections are
	// the established SQL-connection of a connection, or all of them for an
	// SQL-environment.
	mut diag, l1 := transaction_handles(handle_type, h) or { return sql_invalid_handle }
	diag.clear()

	return end_tran(mut diag, handle_type, l1, completion_type) or { diag.error(err) }
}

fn end_tran(mut diag Diagnostics, handle_type i16, l1 []i64, completion_type i16) !i16 {
	// - 3.a.ii, 3.b.ii. A statement or descriptor handle raises an exception
	// condition: CLI-specific condition — invalid attribute identifier.
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
	// L1 only has the active connections (General Rules, 3.d.ii.3), so an
	// SQL-transaction that StartTran started for the SQL-environment, but that
	// isn't in any of its connections yet, isn't ended and stays active.
	if l1.len == 0 {
		return sql_success
	}

	// - 13, 15. SAVEPOINT NAME RELEASE and SAVEPOINT NAME ROLLBACK can only be
	// used with a connection, and the SAVEPOINT NAME must be a savepoint of the
	// current SQL-transaction.
	if completion_type in [sql_savepoint_name_rollback, sql_savepoint_name_release] {
		if handle_type != sql_handle_dbc {
			return sql_invalid_handle
		}
		return end_savepoint(l1[0], completion_type == sql_savepoint_name_rollback)
	}

	// - 9. If any statement of the connections has a deferred parameter number,
	// then an exception condition is raised: CLI-specific condition — function
	// sequence error.
	mut branches := l1.clone()
	if handle_type == sql_handle_dbc {
		branches << active_branches(l1[0])
	}
	for _, stmt in stmts {
		if stmt.dbc in branches {
			stmt.check_deferred()!
		}
	}

	is_commit := completion_type in [sql_commit, sql_commit_and_chain]
	is_chain := completion_type in [sql_commit_and_chain, sql_rollback_and_chain]
	if is_commit && branches.filter(connection_active(it)).len > 1 {
		for dh in branches {
			mut conn := (dbcs[dh] or { continue }).conn or { continue }
			if !conn.in_transaction() {
				continue
			}
			db_query(mut conn, 'SET CONSTRAINTS ALL IMMEDIATE') or {
				for other in branches {
					mut c := (dbcs[other] or { continue }).conn or { continue }
					close_cursors(other, false)
					if c.in_transaction() {
						end_transaction(mut diag, mut c, other, false, false) or {}
					}
				}
				return err
			}
		}
	}
	mut errors := []IError{}
	for dh in branches {
		mut dbc := dbcs[dh] or { continue }
		mut conn := dbc.conn or { continue }

		// - 10, 11. A rollback closes every open cursor, and a commit closes
		// every cursor that isn't holdable.
		close_cursors(dh, is_commit)

		if !conn.in_transaction() {
			continue
		}

		// - 12, 14. The current SQL-transaction is terminated. If CT indicates
		// COMMIT AND CHAIN or ROLLBACK AND CHAIN, then a new SQL-transaction is
		// initiated, with the same access mode, isolation level and condition area
		// limit.
		end_transaction(mut diag, mut conn, dh, is_commit, is_chain) or {
			errors << err
			continue
		}
		if is_chain {
			dbc.autocommit_transaction = false
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

// rollback_branches rolls back the other branches of the SQL-transaction of the
// connection dh, after its own branch was rolled back by an error.
fn rollback_branches(mut diag Diagnostics, dh i64) {
	for h in active_branches(dh) {
		mut conn := (dbcs[h] or { continue }).conn or { continue }
		close_cursors(h, false)
		end_transaction(mut diag, mut conn, h, false, false) or {}
	}
}

// end_savepoint releases, or rolls back to, the savepoint in the SAVEPOINT NAME
// attribute, which is an identifier. A rollback closes every cursor that isn't
// holdable. The others stay open, which is implementation-defined.
//
// - 15.h. The status of cursors from before the savepoint is
// implementation-defined.
// - 15.i. No prepared statement is deallocated.
fn end_savepoint(dh i64, is_rollback bool) !i16 {
	mut dbc := dbcs[dh] or { return sql_invalid_handle }
	mut conn := dbc.conn or { return sql_invalid_handle }
	name := savepoint_identifier(dbc.savepoint_name) or {
		return cli_error('3B001', 'savepoint exception — invalid specification')
	}
	if is_rollback {
		db_query(mut conn, 'ROLLBACK TO SAVEPOINT ${name}')!
		close_cursors(dh, true)
	} else {
		db_query(mut conn, 'RELEASE SAVEPOINT ${name}')!
	}

	return sql_success
}

// savepoint_identifier is a savepoint name as a delimited identifier, so it can't
// be a reserved word or anything other than a name. An error is returned if it
// isn't an identifier.
fn savepoint_identifier(name string) !string {
	if name.len > 2 && name.starts_with('"') && name.ends_with('"') {
		inner := name[1..name.len - 1]
		if inner.replace('""', '').contains('"') {
			return error('not an identifier')
		}

		return name
	}

	is_regular := name.len > 0 && (name[0].is_letter() || name[0] == `_`)
		&& name.bytes().all(it.is_letter() || it.is_digit() || it == `_`)
	if !is_regular {
		return error('not an identifier')
	}

	return '"${name.to_upper()}"'
}

// end_transaction commits or rolls back the SQL-transaction of an established
// connection. A commit that fails rolls back the SQL-transaction instead (General
// Rules 12.d.i and 12.d.iii), which also closes the holdable cursors, unless that
// fails too.
fn end_transaction(mut diag Diagnostics, mut conn vsql.Connection, dh i64, is_commit bool, is_chain bool) ! {
	statement := if is_commit { 'COMMIT' } else { 'ROLLBACK' }
	db_query(mut conn, if is_chain { '${statement} AND CHAIN' } else { statement }) or {
		if !conn.in_transaction() {
			diag.transactions_rolled_back++
			close_cursors(dh, false)
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
