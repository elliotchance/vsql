// prepare.v is for prepared statements.

module vsql

import builtin.closure
import time

// All possible root statments.
type Stmt = AlterSequenceGeneratorStatement
	| AlterTableStatement
	| CloseStatement
	| CommitStatement
	| ConnectStatement
	| CreateIndexStatement
	| DeclareCursor
	| DeleteStatementPositioned
	| DeleteStatementSearched
	| DisconnectStatement
	| DropIndexStatement
	| DropSchemaStatement
	| DropSequenceGeneratorStatement
	| DropTableStatement
	| FetchStatement
	| InsertStatement
	| OpenStatement
	| QueryExpression
	| RollbackStatement
	| SchemaDefinition
	| SequenceGeneratorDefinition
	| SetCatalogStatement
	| SetConnectionStatement
	| SetConstraintsModeStatement
	| SetSchemaStatement
	| SetTransactionStatement
	| StartTransactionStatement
	| TableDefinition
	| UpdateStatementPositioned
	| UpdateStatementSearched

// A prepared statement is compiled and validated, but not executed. It can then
// be executed with a value for each dynamic parameter ("?") in the statement,
// named by its position: "?1", "?2", etc. Each invocation requires all of them
// to be passed in.
//
// A prepared statement isn't deallocated when an SQL-transaction ends, so it
// can still be executed after a COMMIT or ROLLBACK.
pub struct PreparedStmt {
	// ISO/IEC 9075-2:2016(E), 17.7, <commit statement>, General Rules, 11
	// ISO/IEC 9075-2:2016(E), 17.8, <rollback statement>, General Rules, 2.f
	stmt Stmt
	// params can be set on the statement and will be merged with the extra
	// params at execution time. If name collisions occur, the params provided
	// at execution time will take precedence.
	params map[string]Value
	// explain is true if the query was prefixed with EXPLAIN. The EXPLAIN is
	// removed from the query before parsing since this keyword is not part of
	// the SQL standard. It's a <direct implementation-defined statement>.
	//
	// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, Syntax Rules, 3
	explain bool
	// writes is true if a query modifies the database, even though it would
	// otherwise be read only. At the moment this is only when it contains a
	// NEXT VALUE FOR.
	writes bool
	// dynamic_parameters is the number of <dynamic parameter specification>s
	// ("?") in the statement.
	dynamic_parameters int
	// features are the features outside of Core SQL that the statement uses,
	// see features.
	features []string
mut:
	c             &Connection
	elapsed_parse time.Duration
}

// Execute the prepared statement.
pub fn (mut p PreparedStmt) query(params map[string]Value) !Result {
	mut c := p.c

	// The outermost statement can be canceled (see Connection.cancel) until it
	// ends. A statement that's run by another one is part of it.
	mut cancel_state := c.cancel_state
	outermost := cancel_state.compare_and_swap(statement_idle, statement_running)
	defer {
		if outermost {
			cancel_state.store(statement_idle)
		}
	}
	// A statement run by another statement (or from a thread the lifetime
	// doesn't belong to) keeps its closures.
	if c.frame_active || isnil(c.frame_work) {
		return p.query_statement(params)
	}

	c.frame_stmt = unsafe { p }
	c.frame_params = params
	c.frame_active = true
	c.frame_ran = false
	c.frame_err = none
	c.lifetime.frame(c.frame_work) or {
		// A lifetime belongs to the thread that made it, so a connection
		// that's used from another thread needs a new one.
		if !c.frame_ran && err.msg().contains('different thread') {
			c.lifetime = closure.new_lifetime()
			c.lifetime.frame(c.frame_work) or {}
		}
	}
	c.frame_active = false
	c.frame_stmt = unsafe { nil }
	if !c.frame_ran {
		return p.query_statement(params)
	}
	c.lifetime.reclaim_all() or {}

	if c.frame_err !is none {
		return c.frame_err
	}

	return c.frame_result
}

fn (mut p PreparedStmt) query_statement(params map[string]Value) !Result {
	// A statement outside of a transaction is its own transaction, which ends
	// with the statement.
	defer {
		if !p.c.in_transaction() {
			p.c.end_transaction(true)
		}
	}

	result := p.query_internal(params) or { return p.fail(err) }

	// An isolation block that couldn't be ended also fails the statement, see
	// Storage.end_isolation.
	p.c.take_isolation_error() or { return p.fail(err) }

	p.c.finish_write(true) or {
		p.c.unlock_transactions()
		return p.fail(err)
	}
	p.c.unlock_transactions()

	return result
}

// dynamic_parameter_count is the number of dynamic parameters ("?") in the
// statement. Their values are the params "?1", "?2", etc.
pub fn (p PreparedStmt) dynamic_parameter_count() int {
	return p.dynamic_parameters
}

// command_function returns the identifier and code of the statement, from
// Table 37, "SQL-statement codes" in ISO/IEC 9075-2 (the COMMAND_FUNCTION and
// DYNAMIC_FUNCTION of a diagnostics area). A query is a <dynamic select
// statement> ("SELECT CURSOR"). EXPLAIN, DECLARE CURSOR, CREATE INDEX and DROP
// INDEX aren't standard statements, so their codes are negative.
pub fn (p PreparedStmt) command_function() (string, int) {
	// ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>, General Rules, 2.c to 2.e
	if p.explain {
		return 'EXPLAIN', -1
	}

	return match p.stmt {
		AlterSequenceGeneratorStatement { 'ALTER SEQUENCE', 134 }
		AlterTableStatement { 'ALTER TABLE', 4 }
		CloseStatement { 'CLOSE CURSOR', 9 }
		CommitStatement { 'COMMIT WORK', 11 }
		ConnectStatement { 'CONNECT', 13 }
		CreateIndexStatement { 'CREATE INDEX', -3 }
		DeclareCursor { 'DECLARE CURSOR', -2 }
		DeleteStatementPositioned { 'DELETE CURSOR', 18 }
		DeleteStatementSearched { 'DELETE WHERE', 19 }
		DisconnectStatement { 'DISCONNECT', 22 }
		DropIndexStatement { 'DROP INDEX', -4 }
		DropSchemaStatement { 'DROP SCHEMA', 31 }
		DropSequenceGeneratorStatement { 'DROP SEQUENCE', 135 }
		DropTableStatement { 'DROP TABLE', 32 }
		FetchStatement { 'FETCH', 45 }
		InsertStatement { 'INSERT', 50 }
		OpenStatement { 'OPEN', 53 }
		QueryExpression { 'SELECT CURSOR', 85 }
		RollbackStatement { 'ROLLBACK WORK', 62 }
		SchemaDefinition { 'CREATE SCHEMA', 64 }
		SequenceGeneratorDefinition { 'CREATE SEQUENCE', 133 }
		SetCatalogStatement { 'SET CATALOG', 66 }
		SetConnectionStatement { 'SET CONNECTION', 67 }
		SetConstraintsModeStatement { 'SET CONSTRAINT', 68 }
		SetSchemaStatement { 'SET SCHEMA', 74 }
		SetTransactionStatement { 'SET TRANSACTION', 75 }
		StartTransactionStatement { 'START TRANSACTION', 111 }
		TableDefinition { 'CREATE TABLE', 77 }
		UpdateStatementPositioned { 'UPDATE CURSOR', 81 }
		UpdateStatementSearched { 'UPDATE WHERE', 82 }
	}
}

// positioned_cursor returns the name of the cursor that a positioned DELETE or
// UPDATE references (as the name of the cursor, not as it was written), or an
// empty string for any other statement.
pub fn (p PreparedStmt) positioned_cursor() string {
	return match p.stmt {
		DeleteStatementPositioned { p.stmt.cursor_name }
		UpdateStatementPositioned { p.stmt.cursor_name }
		else { '' }
	}
}

// columns returns the columns of the result of a query, without executing it,
// or none for a statement that doesn't return rows. Like query, params must
// have a value for each parameter, which gives it a data type.
pub fn (mut p PreparedStmt) columns(params map[string]Value) ![]Column {
	stmt := p.stmt
	if stmt !is QueryExpression {
		return []Column{}
	}

	mut all_params := params.clone()
	for k, v in p.params {
		if k !in all_params {
			all_params[k] = v
		}
	}

	if p.explain {
		return stmt.explain(mut p.c, all_params, p.elapsed_parse)!.columns
	}

	p.c.open_read_connection()!
	defer {
		p.c.release_read_connection()
	}

	mut plan := create_plan(stmt, all_params, mut p.c)!

	return plan.columns()
}

// fail ends a statement that failed with err.
fn (mut p PreparedStmt) fail(err IError) IError {
	// A statement that fails must not change anything, but the transaction it's
	// in continues, unless the exception condition is a transaction rollback.
	//
	// ISO/IEC 9075-2:2016(E), 4.39.5, SQL-statement atomicity and statement execution contexts
	// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>, General Rules, 18.b.i
	// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, General Rules, 8.b
	p.c.take_isolation_error() or {}
	p.c.finish_write(false) or {}

	// The transaction isn't active for a COMMIT that had nothing to commit.
	failure := if p.stmt is CommitStatement && !p.explain && p.c.in_transaction() {
		commit_error(err)
	} else {
		err
	}
	if sqlstate_from_int(failure.code()).starts_with('40') {
		// The exception condition says that the transaction was rolled back, so
		// if it wasn't, the client must be told that it's still active instead.
		p.c.rollback_after_error() or {
			return error_with_code('${failure.msg()}, but the transaction is still active because it could not be rolled back: ${err.msg()}',
				err.code())
		}
	}
	p.c.unlock_transactions()

	return failure
}

fn (mut p PreparedStmt) query_internal(params map[string]Value) !Result {
	mut all_params := params.clone()
	for k, v in p.params {
		if k !in all_params {
			all_params[k] = v
		}
	}

	p.c.begin_row()
	p.c.set_statement_timestamp()
	p.c.subquery_results = map[voidptr]SubqueryResult{}

	// - 17.2 GR 7. A statement that isn't in an SQL-transaction is in one of its
	// own. EXPLAIN doesn't run the statement, so it doesn't use up a SET
	// TRANSACTION.
	if !p.explain && !p.c.is_active() && p.is_transaction_initiating() {
		p.c.initiate_transaction(p.c.next_transaction or { p.c.enduring_characteristics() })
		if !p.c.read_only && p.changes_database() && p.c.isolation_level.locks_transaction() {
			p.c.lock_transaction(false)!
		}
	}

	// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>, General Rules, 11
	// ISO/IEC 9075-2:2016(E), 14.9, <delete statement: searched>, General Rules, 1
	// ISO/IEC 9075-2:2016(E), 14.11, <insert statement>, General Rules, 1
	// ISO/IEC 9075-2:2016(E), 14.14, <update statement: searched>, General Rules, 1
	// ISO/IEC 9075-2:2016(E), 15.5, Effect of a positioned delete, General Rules, 2
	// ISO/IEC 9075-2:2016(E), 15.6, Effect of a positioned update, General Rules, 2
	if !p.explain && p.c.read_only && p.changes_database() {
		return sqlstate_25006('cannot execute ${p.changes_database_name()}')
	}

	stmt := p.stmt
	match stmt {
		ConnectStatement, SetConnectionStatement, DisconnectStatement {
			return sqlstate_42601('a connection statement can only be used in direct SQL')
		}
		AlterSequenceGeneratorStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		AlterTableStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		CommitStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		CreateIndexStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		DropIndexStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		SchemaDefinition {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		SequenceGeneratorDefinition {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		TableDefinition {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		CloseStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		DeclareCursor {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse, p.writes)
		}
		DeleteStatementPositioned {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		FetchStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		OpenStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		UpdateStatementPositioned {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		DeleteStatementSearched {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		DropSchemaStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		DropSequenceGeneratorStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		DropTableStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		InsertStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		RollbackStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		SetCatalogStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		SetConstraintsModeStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		SetSchemaStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		QueryExpression {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse, p.writes)
		}
		SetTransactionStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		StartTransactionStatement {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
		UpdateStatementSearched {
			if p.explain {
				return stmt.explain(mut p.c, all_params, p.elapsed_parse)
			}

			return stmt.execute(mut p.c, all_params, p.elapsed_parse)
		}
	}
}
