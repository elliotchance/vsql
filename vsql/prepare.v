// prepare.v is for prepared statements.

module vsql

import time

// A prepared statement is compiled and validated, but not executed. It can then
// be executed with a set of host parameters to be substituted into the
// statement. Each invocation requires all host parameters to be passed in.
pub struct PreparedStmt {
	stmt Stmt
	// params can be set on the statement and will be merged with the extra
	// params at execution time. If name collisions occur, the params provided
	// at execution time will take precedence.
	params map[string]Value
	// explain is true if the query was prefixed with EXPLAIN. The EXPLAIN is
	// removed from the query before parsing since this keyword is not part of
	// the SQL standard.
	explain bool
mut:
	c             &Connection
	elapsed_parse time.Duration
}

// Execute the prepared statement.
pub fn (mut p PreparedStmt) query(params map[string]Value) !Result {
	return p.query_internal(params) or {
		p.c.transaction_aborted()
		return err
	}
}

fn (mut p PreparedStmt) query_internal(params map[string]Value) !Result {
	mut all_params := params.clone()
	for k, v in p.params {
		if k !in all_params {
			all_params[k] = v
		}
	}

	stmt := p.stmt
	match stmt {
		AlterSequenceGeneratorStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN ALTER SEQUENCE')
			}

			return execute_alter_sequence(mut p.c, stmt, p.elapsed_parse)
		}
		CommitStmt {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN COMMIT')
			}

			// See transaction.v
			return execute_commit(mut p.c, stmt, p.elapsed_parse)
		}
		SchemaDefinition {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN CREATE SCHEMA')
			}

			return execute_create_schema(mut p.c, stmt, p.elapsed_parse)
		}
		SequenceGeneratorDefinition {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN CREATE SEQUENCE')
			}

			return execute_create_sequence(mut p.c, stmt, p.elapsed_parse)
		}
		TableDefinition {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN CREATE TABLE')
			}

			return execute_create_table(mut p.c, stmt, p.elapsed_parse)
		}
		DeleteStmt {
			return execute_delete(mut p.c, stmt, all_params, p.elapsed_parse, p.explain)
		}
		DropSchemaStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN DROP SCHEMA')
			}

			return execute_drop_schema(mut p.c, stmt, p.elapsed_parse)
		}
		DropSequenceGeneratorStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN DROP SEQUENCE')
			}

			return execute_drop_sequence(mut p.c, stmt, p.elapsed_parse)
		}
		DropTableStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN DROP TABLE')
			}

			return execute_drop_table(mut p.c, stmt, p.elapsed_parse)
		}
		InsertStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN INSERT')
			}

			return execute_insert(mut p.c, stmt, all_params, p.elapsed_parse)
		}
		RollbackStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN ROLLBACK')
			}

			// See transaction.v
			return execute_rollback(mut p.c, stmt, p.elapsed_parse)
		}
		SetCatalogStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN SET CATALOG')
			}

			return execute_set_catalog(mut p.c, stmt, p.elapsed_parse)
		}
		SetSchemaStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN SET SCHEMA')
			}

			return execute_set_schema(mut p.c, stmt, p.elapsed_parse)
		}
		QueryExpression {
			return execute_select(mut p.c, stmt, all_params, p.elapsed_parse, p.explain)
		}
		StartTransactionStatement {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN START TRANSACTION')
			}

			// See transaction.v
			return execute_start_transaction(mut p.c, stmt, p.elapsed_parse)
		}
		UpdateStatementSearched {
			return execute_update(mut p.c, stmt, all_params, p.elapsed_parse, p.explain)
		}
	}
}
