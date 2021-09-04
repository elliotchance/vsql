// prepare.v is for prepared statements. A prepared statement is compiled and
// validated, but not executed. It can then be executed with a set of host
// parameters to be substituted into the statement. Each invocation requires all
// host parameters to be passed in.

module vsql

struct PreparedStmt {
	stmt Stmt
	// params can be set on the statement and will be merged with the extra
	// params at execution time. If name collisions occur, the params provided
	// at execution time will take precedence.
	params map[string]Value
mut:
	c &Connection
}

pub fn (mut p PreparedStmt) query(params map[string]Value) ?Result {
	stmt := p.stmt

	mut all_params := params.clone()
	for k, v in p.params {
		if k !in all_params {
			all_params[k] = v
		}
	}

	match stmt {
		CreateTableStmt {
			return execute_create_table(mut p.c, stmt)
		}
		DeleteStmt {
			return execute_delete(mut p.c, stmt, all_params)
		}
		DropTableStmt {
			return execute_drop_table(mut p.c, stmt)
		}
		InsertStmt {
			return execute_insert(mut p.c, stmt, all_params)
		}
		SelectStmt {
			return execute_select(mut p.c, stmt, all_params)
		}
		UpdateStmt {
			return execute_update(mut p.c, stmt, all_params)
		}
	}
}
