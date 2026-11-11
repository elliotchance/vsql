module vsql

// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>
//
// Specify direct execution of SQL.
//
// The concepts are described by:
//
// ISO/IEC 9075-2:2016(E), 4.31, Direct invocation of SQL
// ISO/IEC 9075-2:2016(E), 4.39, SQL-statements

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
// 02000 (no data). A schema statement and a data statement can be in the same
// SQL-transaction. EXPLAIN is transaction-initiating, like the statement it
// explains. A query can't have an <updatability clause> (see
// check_direct_query).
//
// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, General Rules, 1, 5.c.ii, 5.c.vi, 7, 8.a and 9
pub fn (mut conn Connection) direct(sql_stmt string, options DirectOptions) !Result {
	text := direct_statement_text(sql_stmt)!
	tokens := tokenize(text)!
	mut prepared := conn.parse(text)!
	check_direct_parameters(tokens)!
	check_direct_query(prepared.stmt)!

	// The SQL-transaction has the characteristics of a SET TRANSACTION. Each
	// constraint has its initial constraint mode, rather than immediate.
	//
	// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, General Rules, 5.c.iii.1.A, 5.c.iii.1.B and 5.c.iii.2
	// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, General Rules, 5.c.iii.2.B to 5.c.iii.2.D
	if !options.autocommit && !conn.in_transaction() && prepared.is_transaction_initiating() {
		if !prepared.writes && prepared.stmt is QueryExpression {
			// Starting the transaction would take the isolation lock, which
			// needs the isolation file (that may not be possible to create for
			// a database that can only be read), and would stop other
			// connections, so it isn't started until a statement changes
			// something. Until then, it's isolated by check_direct_query rather
			// than a lock.
			if !conn.direct_query_transaction {
				conn.initiate_transaction(conn.next_transaction or { conn.enduring_characteristics() })
				conn.direct_query_headers = map[string]Header{}
			}
			conn.direct_query_transaction = true
		} else if conn.direct_query_transaction
			&& (prepared.stmt is CommitStatement || prepared.stmt is RollbackStatement) {
			// With AND CHAIN, the next SQL-transaction has the same characteristics
			// and hasn't changed anything either.
			conn.direct_query_transaction = prepared.is_chain()
			msg := if prepared.stmt is CommitStatement { 'COMMIT' } else { 'ROLLBACK' }
			return new_result_msg(msg, prepared.elapsed_parse, 0)
		} else if prepared.stmt !is CommitStatement && prepared.stmt !is RollbackStatement {
			// It's started like a START TRANSACTION, which unlocks the file
			// when it finishes, but it keeps the characteristics of a SET
			// TRANSACTION (or of the SQL-transaction that a query started).
			characteristics := if conn.direct_query_transaction {
				conn.current_characteristics()
			} else {
				conn.next_transaction or { conn.enduring_characteristics() }
			}
			mut start := PreparedStmt{
				stmt: Stmt(StartTransactionStatement{
					implicit: characteristics
				})
				c:    &conn
			}
			start.query(map[string]Value{})!
			if conn.direct_query_transaction {
				conn.check_direct_transaction() or {
					conn.query('ROLLBACK')!
					return err
				}
			}
			conn.direct_query_transaction = false
		}
	}

	if conn.direct_query_transaction && prepared.stmt is StartTransactionStatement {
		return sqlstate_25001()
	}

	result := prepared.query(map[string]Value{})!

	if conn.direct_query_transaction && prepared.stmt is QueryExpression {
		conn.check_direct_query()!
	}

	// The rows of a query are the rows of the Result.
	//
	// ISO/IEC 9075-2:2016(E), 22.2, <direct select statement: multiple rows>, General Rules, 2.a and 2.b
	if prepared.stmt is QueryExpression && !prepared.explain && result.rows.len == 0 {
		conn.add_warning(sqlstate_02000())
	}

	return result
}

// direct_features returns the Feature IDs outside of Core SQL that a <direct
// SQL statement> of Connection.direct or Agent.direct uses (see the SQL Flagging
// docs), sorted and without duplicates. The statement is only parsed, not
// executed.
//
// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, Conformance Rules, 1
pub fn direct_features(sql_stmt string) ![]string {
	mut stack := []YYSymType{}
	stmt, _, tokens, features := parse_sql(direct_statement_text(sql_stmt)!, mut stack)!
	check_direct_parameters(tokens)!
	check_direct_query(stmt)!

	return unique_features(features, 'B021')
}

// direct_statement_text returns the statement of a <direct SQL statement>. The
// <semicolon> is part of the <direct SQL statement>.
//
// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, General Rules, 5.a
fn direct_statement_text(sql_stmt string) !string {
	statements, rest := split_terminated_statements(sql_stmt)
	if statements.len != 1 || rest != '' {
		return sqlstate_42601('a direct SQL statement is one statement that ends with a semicolon')
	}

	return statements[0]
}

// check_direct_query is an error for a query that has an <updatability
// clause>, which is only for a cursor (see PreparedStmt.open_cursor).
//
// ISO/IEC 9075-2:2016(E), 22.2, <direct select statement: multiple rows>, Syntax Rules, 2
fn check_direct_query(stmt Stmt) ! {
	if stmt is QueryExpression && stmt.updatability != none {
		return sqlstate_42601('FOR READ ONLY and FOR UPDATE can only be used for a cursor')
	}
}

// check_direct_parameters is an error for a "?" or a host parameter, since
// there is nothing to provide the value.
//
// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 22.2, <direct select statement: multiple rows>, Syntax Rules, 1
fn check_direct_parameters(tokens []Token) ! {
	if tokens.any(it.token in [token_operator_question_mark, token_operator_colon]) {
		return sqlstate_42601('a direct SQL statement cannot contain a parameter')
	}
}

// is_transaction_initiating is true for a statement that starts an
// SQL-transaction when there isn't one. START TRANSACTION starts one itself.
// The SQL-session statements, the connection statements, SET CONSTRAINTS and
// SET TRANSACTION don't start one. A query is a <direct select statement:
// multiple rows>, which starts one.
//
// ISO/IEC 9075-2:2016(E), 4.39.4, SQL-statements and transaction states
// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, General Rules, 1.a and 1.b
// is_chain is true for a COMMIT or ROLLBACK with AND CHAIN.
fn (p PreparedStmt) is_chain() bool {
	stmt := p.stmt
	return match stmt {
		CommitStatement, RollbackStatement { stmt.chain }
		else { false }
	}
}

fn (p PreparedStmt) is_transaction_initiating() bool {
	return p.stmt !is StartTransactionStatement && p.stmt !is SetCatalogStatement
		&& p.stmt !is SetSchemaStatement && p.stmt !is SetConstraintsModeStatement
		&& p.stmt !is SetTransactionStatement && p.stmt !is SetSessionCharacteristicsStatement
		&& p.stmt !is SetNamesStatement
		&& p.stmt !is ConnectStatement
		&& p.stmt !is SetConnectionStatement && p.stmt !is DisconnectStatement
}

// is_active is true when the connection is an active SQL-connection
// (ISO/IEC 9075-2:2016(E), 4.42), which is when it has an SQL-transaction,
// including one that Connection.direct hasn't started in storage yet.
fn (conn Connection) is_active() bool {
	return conn.in_transaction() || conn.direct_query_transaction
}
