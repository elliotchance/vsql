// planner.v contains the query planner which determines the best strategy for
// finding rows. The plan is built from a stack of operations, where each
// operation may take in rows but will always produce rows that can be fed into
// the next operation. You can find the operations in:
//
//   LimitOperation          table.v
//   TableOperation          table.v
//   WhereOperation          where.v
//   VirtualTableOperation   virtual_table.v

module vsql

import time

interface PlanOperation {
	execute(row []Row) ?[]Row
	str() string
}

fn create_plan(stmt Stmt, params map[string]Value, c Connection) ?Plan {
	match stmt {
		DeleteStmt { return create_delete_plan(stmt, params, c) }
		SelectStmt { return create_select_plan(stmt, params, c) }
		UpdateStmt { return create_update_plan(stmt, params, c) }
		else { return error('Cannot plan for $stmt') }
	}
}

fn create_basic_plan(table_name string, where Expr, params map[string]Value, c Connection) ?Plan {
	mut plan := Plan{}

	if table_name in c.storage.tables {
		plan.operations << TableOperation{table_name, c.storage.tables[table_name], NoExpr{}, params, c, c.storage}
	} else {
		return sqlstate_42p01(table_name)
	}

	if where !is NoExpr {
		plan.operations << WhereOperation{where, params, c}
	}

	return plan
}

fn create_delete_plan(stmt DeleteStmt, params map[string]Value, c Connection) ?Plan {
	return create_basic_plan(identifier_name(stmt.table_name), stmt.where, params, c)
}

fn create_update_plan(stmt UpdateStmt, params map[string]Value, c Connection) ?Plan {
	return create_basic_plan(identifier_name(stmt.table_name), stmt.where, params, c)
}

fn create_select_plan(stmt SelectStmt, params map[string]Value, c Connection) ?Plan {
	mut plan := Plan{}

	table_name := identifier_name(stmt.from)

	// Check virtual table first.
	if table_name in c.virtual_tables {
		plan.operations << VirtualTableOperation{table_name, c.virtual_tables[table_name]}
	}
	// Now check for a regular table.
	else if table_name in c.storage.tables {
		plan.operations << TableOperation{table_name, c.storage.tables[table_name], stmt.offset, params, c, c.storage}
	} else {
		return sqlstate_42p01(table_name)
	}

	if stmt.where !is NoExpr {
		plan.operations << WhereOperation{stmt.where, params, c}
	}

	if stmt.fetch !is NoExpr {
		plan.operations << LimitOperation{stmt.fetch, params, c}
	}

	return plan
}

// The Plan itself is a PlanOperation. This allows more complex operations to be
// nested later.
struct Plan {
mut:
	operations []PlanOperation
	params     map[string]Value
}

fn (o Plan) execute(_ []Row) ?[]Row {
	mut rows := []Row{}
	for operation in o.operations {
		rows = operation.execute(rows) ?
	}

	return rows
}

fn (p Plan) str() string {
	return p.operations.map(it.str()).join('\n')
}

fn (p Plan) explain(elapsed_parse time.Duration) Result {
	mut rows := []Row{}
	for operation in p.operations {
		rows << new_row({
			'EXPLAIN': new_varchar_value(operation.str(), 0)
		})
	}

	return new_result(['EXPLAIN'], rows, elapsed_parse, 0)
}
