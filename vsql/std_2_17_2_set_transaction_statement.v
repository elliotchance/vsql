module vsql

import time

// ISO/IEC 9075-2:2023, 17.2, <set transaction statement>
//
// Set the characteristics of the next SQL-transaction for the SQL-agent.
//
// LOCAL (Feature T251) sets the characteristics of the branch of the
// SQL-transaction on this SQL-server (T262), before the branch is started. The
// characteristics that aren't given are those of the SQL-transaction, and the
// branch can't be less strict than it.

struct SetTransactionStatement {
	modes []TransactionMode
	local bool
}

fn (stmt SetTransactionStatement) execute(mut conn Connection, params map[string]Value, elapsed_parse time.Duration) !Result {
	t := start_timer()

	check_transaction_modes(stmt.modes)!

	if stmt.local {
		// ISO/IEC 9075-2:2023, 17.2, <set transaction statement>, Syntax Rules, 1
		if stmt.modes.any(it is DiagnosticsSize) {
			return sqlstate_42601('DIAGNOSTICS SIZE cannot be used with LOCAL')
		}

		// ISO/IEC 9075-2:2023, 17.2, <set transaction statement>, General Rules, 1.b.ii and 1.b.iii
		if conn.is_active() {
			return sqlstate_25002()
		}
		sql_transaction := conn.branch_of or { return sqlstate_25005() }

		mut read_only := sql_transaction.read_only
		mut isolation_level := sql_transaction.isolation_level
		for mode in stmt.modes {
			match mode {
				TransactionAccessMode {
					read_only = mode == .read_only
				}
				IsolationLevel {
					isolation_level = mode
					conn.check_held_cursors(mode)!
				}
				DiagnosticsSize {}
			}
		}
		branch := TransactionCharacteristics{
			...sql_transaction
			read_only:       read_only || isolation_level == .read_uncommitted
			isolation_level: isolation_level
		}

		// ISO/IEC 9075-2:2023, 17.2, <set transaction statement>, General Rules, 1.b.iv
		if sql_transaction.read_only && !branch.read_only {
			return sqlstate_25003()
		}

		// ISO/IEC 9075-2:2023, 17.2, <set transaction statement>, General Rules, 1.b.v to 1.b.vii
		if sql_transaction.isolation_level != .read_uncommitted
			&& int(branch.isolation_level) < int(sql_transaction.isolation_level) {
			return sqlstate_25004()
		}

		conn.next_transaction = branch

		return new_result_msg('SET LOCAL TRANSACTION', elapsed_parse, t.elapsed())
	}

	// An SQL-transaction that's active on another SQL-connection is active too.
	//
	// ISO/IEC 9075-2:2023, 17.2, <set transaction statement>, General Rules, 1.a.i
	if conn.is_active() || conn.branch_of != none {
		return sqlstate_25001()
	}

	// The SQL-transaction isn't initiated yet.
	//
	// ISO/IEC 9075-2:2023, 17.2, <set transaction statement>, General Rules, 7
	conn.next_transaction = new_transaction_characteristics(mut conn, params, stmt.modes)!

	return new_result_msg('SET TRANSACTION', elapsed_parse, t.elapsed())
}

fn (stmt SetTransactionStatement) explain(mut _ Connection, _ map[string]Value, _ time.Duration) !Result {
	return sqlstate_42601('Cannot EXPLAIN SET TRANSACTION')
}
