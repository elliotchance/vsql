// prepare.v is for prepared statements.

module vsql

import time

// All possible root statments.
type Stmt = AlterSequenceGeneratorStatement
	| CommitStatement
	| DeleteStatementSearched
	| DropSchemaStatement
	| DropSequenceGeneratorStatement
	| DropTableStatement
	| InsertStatement
	| QueryExpression
	| RollbackStatement
	| SchemaDefinition
	| SequenceGeneratorDefinition
	| SetCatalogStatement
	| SetSchemaStatement
	| StartTransactionStatement
	| TableDefinition
	| UpdateStatementSearched

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
