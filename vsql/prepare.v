// prepare.v is for prepared statements. A prepared statement is compiled and
// validated, but not executed. It can then be executed with a set of host
// parameters to be substituted into the statement. Each invocation requires all
// host parameters to be passed in.

module vsql

struct PreparedStmt {
	stmt Stmt
mut:
	c &Connection
}

pub fn (mut p PreparedStmt) query(params map[string]Value) ?Result {
	stmt := p.stmt

	match stmt {
		CreateTableStmt {
			return execute_create_table(mut p.c, stmt)
		}
		DeleteStmt {
			return execute_delete(mut p.c, stmt, params)
		}
		DropTableStmt {
			return execute_drop_table(mut p.c, stmt)
		}
		InsertStmt {
			return execute_insert(mut p.c, stmt, params)
		}
		SelectStmt {
			return execute_select(mut p.c, stmt, params)
		}
		UpdateStmt {
			return execute_update(mut p.c, stmt, params)
		}
	}
}
