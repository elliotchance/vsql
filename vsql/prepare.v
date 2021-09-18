// prepare.v is for prepared statements. A prepared statement is compiled and
// validated, but not executed. It can then be executed with a set of host
// parameters to be substituted into the statement. Each invocation requires all
// host parameters to be passed in.

module vsql

import time

struct PreparedStmt {
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

pub fn (mut p PreparedStmt) query(params map[string]Value) ?Result {
	mut all_params := params.clone()
	for k, v in p.params {
		if k !in all_params {
			all_params[k] = v
		}
	}

	stmt := p.stmt
	match stmt {
		CreateTableStmt {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN CREATE TABLE')
			}

			return execute_create_table(mut p.c, stmt, p.elapsed_parse)
		}
		DeleteStmt {
			return execute_delete(mut p.c, stmt, all_params, p.elapsed_parse, p.explain)
		}
		DropTableStmt {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN DROP TABLE')
			}

			return execute_drop_table(mut p.c, stmt, p.elapsed_parse)
		}
		InsertStmt {
			if p.explain {
				return sqlstate_42601('Cannot EXPLAIN INSERT')
			}

			return execute_insert(mut p.c, stmt, all_params, p.elapsed_parse)
		}
		SelectStmt {
			return execute_select(mut p.c, stmt, all_params, p.elapsed_parse, p.explain)
		}
		UpdateStmt {
			return execute_update(mut p.c, stmt, all_params, p.elapsed_parse, p.explain)
		}
	}
}
