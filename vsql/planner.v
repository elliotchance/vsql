// planner.v contains the query planner which determines the best strategy for
// finding rows. The plan is built from a stack of operations, where each
// operation may take in rows but will always produce rows that can be fed into
// the next operation. You can find the operations in:
//
//   LimitOperation          table.v
//   PrimaryKeyOperation     walk.v
//   TableOperation          table.v
//   WhereOperation          where.v
//   ValuesOperation         values.v
//   VirtualTableOperation   virtual_table.v

module vsql

import time

interface PlanOperation {
	str() string
mut:
	execute(row []Row) ?[]Row
}

fn create_plan(stmt Stmt, params map[string]Value, c &Connection) ?Plan {
	match stmt {
		DeleteStmt { return create_delete_plan(stmt, params, c) }
		QueryExpression { return create_query_expression_plan(stmt, params, c) }
		UpdateStmt { return create_update_plan(stmt, params, c) }
		else { return error('Cannot plan for $stmt') }
	}
}

fn create_basic_plan(body SimpleTable, offset Expr, params map[string]Value, c &Connection, allow_virtual bool) ?Plan {
	match body {
		SelectStmt {
			return create_select_plan(body, offset, params, c, allow_virtual)
		}
		// VALUES
		[]RowExpr {
			mut plan := Plan{}

			plan.operations << ValuesOperation{
				rows: body
				conn: c
				params: params
			}

			return plan
		}
	}
}

fn create_select_plan(body SelectStmt, offset Expr, params map[string]Value, c &Connection, allow_virtual bool) ?Plan {
	mut plan := Plan{}
	mut covered_by_pk := false
	from_clause := body.table_expression.from_clause.body

	match from_clause {
		Identifier {
			table_name := from_clause.name
			where := body.table_expression.where_clause

			if allow_virtual && table_name in c.virtual_tables {
				plan.operations << VirtualTableOperation{table_name, c.virtual_tables[table_name]}
			} else if table_name in c.storage.tables {
				table := c.storage.tables[table_name]

				// This is a special case to handle "PRIMARY KEY = INTEGER".
				if table.primary_key.len > 0 && where is BinaryExpr {
					left := where.left
					right := where.right
					if where.op == '=' && left is Identifier {
						if left.name == table.primary_key[0] {
							covered_by_pk = true
							plan.operations << PrimaryKeyOperation{table, right, right, params, c}
						}
					}
				}

				if !covered_by_pk {
					plan.operations << TableOperation{table_name, c.storage.tables[table_name], offset, params, c, c.storage}
				}
			} else {
				return sqlstate_42p01(table_name)
			}

			if where !is NoExpr && !covered_by_pk {
				plan.operations << WhereOperation{where, params, c}
			}
		}
		QueryExpression {
			rows := from_clause.body as []RowExpr
			plan.operations << new_values_operation(rows, offset, body.table_expression.from_clause.correlation,
				c, params) ?
		}
	}

	return plan
}

fn create_delete_plan(stmt DeleteStmt, params map[string]Value, c &Connection) ?Plan {
	select_stmt := SelectStmt{
		table_expression: TableExpression{
			from_clause: TablePrimary{
				body: new_identifier(stmt.table_name)
			}
			where_clause: stmt.where
		}
	}

	return create_select_plan(select_stmt, NoExpr{}, params, c, false)
}

fn create_update_plan(stmt UpdateStmt, params map[string]Value, c &Connection) ?Plan {
	select_stmt := SelectStmt{
		table_expression: TableExpression{
			from_clause: TablePrimary{
				body: new_identifier(stmt.table_name)
			}
			where_clause: stmt.where
		}
	}

	return create_select_plan(select_stmt, NoExpr{}, params, c, false)
}

fn create_query_expression_plan(stmt QueryExpression, params map[string]Value, c &Connection) ?Plan {
	mut plan := create_basic_plan(stmt.body, stmt.offset, params, c, true) ?

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

fn (mut o Plan) execute(_ []Row) ?[]Row {
	mut rows := []Row{}
	for mut operation in o.operations {
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
