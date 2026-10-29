module vsql

// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>
//
// Specify direct execution of SQL.

// DirectOptions are the options for Connection.direct.
@[params]
pub struct DirectOptions {
pub:
	// autocommit runs a statement that isn't inside a START TRANSACTION in a
	// transaction of its own, which is committed when the statement finishes,
	// like query. The standard doesn't have autocommit, which is the same as
	// false.
	autocommit bool
}

// direct executes a <direct SQL statement>, which is one statement that ends
// with a semicolon. This is how "vsql cli" runs statements. Unless autocommit
// is used, a statement that isn't inside a START TRANSACTION doesn't run in a
// transaction of its own, unlike query. Instead, a transaction-initiating
// statement (any statement other than SET CATALOG, SET SCHEMA and SET
// CONSTRAINTS) starts an SQL-transaction that stays active until it's
// committed or rolled back. An empty result of a query also has the warning
// 02000 (no data).
pub fn (mut conn Connection) direct(sql_stmt string, options DirectOptions) !Result {
	// - Format. The <semicolon> is part of the <direct SQL statement>.
	statements, rest := split_terminated_statements(sql_stmt)
	if statements.len != 1 || rest != '' {
		return sqlstate_42601('a direct SQL statement is one statement that ends with a semicolon')
	}

	tokens := tokenize(statements[0])!
	mut prepared := conn.prepare(statements[0])!

	// - SR 1. There is nothing to provide the value of a "?" or a host
	// parameter.
	if prepared.dynamic_parameters > 0 || tokens.any(it.token == token_operator_colon) {
		return sqlstate_42601('a direct SQL statement cannot contain a parameter')
	}

	// - GR 5.c.iii.1.A.
	if !options.autocommit && !conn.in_transaction() && prepared.is_transaction_initiating() {
		if !prepared.writes && prepared.stmt is QueryExpression {
			// Starting the transaction in each catalog needs a write lock (and
			// fails for a database that can only be read). With READ COMMITTED,
			// a query sees the same rows without one, so it isn't started until
			// a statement changes something. See #672.
			if !conn.direct_query_transaction {
				conn.initiate_transaction(conn.next_condition_area_limit)
			}
			conn.direct_query_transaction = true
		} else if conn.direct_query_transaction
			&& (prepared.stmt is CommitStatement || prepared.stmt is RollbackStatement) {
			conn.direct_query_transaction = false
			msg := if prepared.stmt is CommitStatement { 'COMMIT' } else { 'ROLLBACK' }
			return new_result_msg(msg, prepared.elapsed_parse, 0)
		} else {
			// It's started like a START TRANSACTION, which unlocks the file
			// when it finishes, but it keeps the DIAGNOSTICS SIZE of a SET
			// TRANSACTION (or of the SQL-transaction that a query started).
			limit := if conn.direct_query_transaction {
				conn.condition_area_limit
			} else {
				conn.next_condition_area_limit
			}
			conn.query('START TRANSACTION')!
			conn.initiate_transaction(limit)
			conn.direct_query_transaction = false
		}
	}

	if conn.direct_query_transaction && prepared.stmt is StartTransactionStatement {
		return sqlstate_25001()
	}

	result := prepared.query(map[string]Value{})!

	// - 22.2 GR 2.a.
	if prepared.stmt is QueryExpression && !prepared.explain && result.rows.len == 0 {
		conn.add_warning(sqlstate_02000())
	}

	return result
}

// is_transaction_initiating is true for a statement that starts an
// SQL-transaction when there isn't one (ISO/IEC 9075-2:2016(E), 4.39.4). START
// TRANSACTION starts one itself. The SQL-session statements, the connection
// statements, SET CONSTRAINTS and SET TRANSACTION don't start one.
fn (p PreparedStmt) is_transaction_initiating() bool {
	return p.stmt !is StartTransactionStatement && p.stmt !is SetCatalogStatement
		&& p.stmt !is SetSchemaStatement && p.stmt !is SetConstraintsModeStatement
		&& p.stmt !is SetTransactionStatement && p.stmt !is ConnectStatement
		&& p.stmt !is SetConnectionStatement && p.stmt !is DisconnectStatement
}

// is_active is true when the connection is an active SQL-connection
// (ISO/IEC 9075-2:2016(E), 4.42), which is when it has an SQL-transaction,
// including one that Connection.direct hasn't started in storage yet.
fn (conn Connection) is_active() bool {
	return conn.in_transaction() || conn.direct_query_transaction
}
