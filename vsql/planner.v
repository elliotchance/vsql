// planner.v contains the query planner which determines the best strategy for
// finding rows. The plan is built from a stack of operations, where each
// operation may take in rows but will always produce rows that can be fed into
// the next operation. You can find the operations in:
//
//   LimitOperation          limit.v
//   PrimaryKeyOperation     walk.v
//   TableOperation          table.v
//   WhereOperation          where.v
//   ValuesOperation         values.v
//   VirtualTableOperation   virtual_table.v

module vsql

import time

interface PlanOperation {
	str() string
	// A PlanOperation may return different columns from the input rows. This
	// will return the columns (including their types) from the result of this
	// operation. It's safe to invoke this before execute() and invokes multiple
	// times if needed.
	columns() Columns
mut:
	execute(row []Row) ?[]Row
}

fn create_plan(stmt Stmt, params map[string]Value, c &Connection) ?Plan {
	match stmt {
		DeleteStmt { return create_delete_plan(stmt, params, c) }
		QueryExpression { return create_query_expression_plan(stmt, params, c, Correlation{}) }
		UpdateStmt { return create_update_plan(stmt, params, c) }
		else { return error('Cannot create plan for $stmt') }
	}
}

fn create_basic_plan(body SimpleTable, offset Expr, params map[string]Value, c &Connection, allow_virtual bool, correlation Correlation) ?Plan {
	match body {
		SelectStmt {
			return create_select_plan(body, offset, params, c, allow_virtual)
		}
		// VALUES
		[]RowExpr {
			mut plan := Plan{}

			plan.operations << new_values_operation(body, NoExpr{}, correlation, c, params) ?

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
							plan.operations << new_primary_key_operation(table, right,
								right, params, c)
						}
					}
				}

				if !covered_by_pk {
					columns := columns_from_select(body, table, params, c) ?
					plan.operations << TableOperation{table_name, false, c.storage.tables[table_name], params, c, columns, body.exprs, plan.subplans, c.storage}
				}
			} else {
				return sqlstate_42p01(table_name)
			}

			if where !is NoExpr && !covered_by_pk {
				last_operation := plan.operations[plan.operations.len - 1]
				plan.operations << new_where_operation(where, params, c, last_operation.columns())
			}
		}
		QueryExpression {
			// TODO(elliotchance): Needs to increment.
			mut table_name := '\$1'

			if body.table_expression.from_clause.correlation.name.name != '' {
				table_name = body.table_expression.from_clause.correlation.name.name
			}

			subplan := create_query_expression_plan(from_clause, params, c, body.table_expression.from_clause.correlation) ?
			plan.subplans[table_name] = subplan

			// NOTE: This has to be assigned to a variable otherwise the value
			// is lost. This must be a bug in V.
			t := Table{
				columns: subplan.columns()
			}

			columns := columns_from_select(body, t, params, c) ?
			plan.operations << TableOperation{table_name, true, t, params, c, columns, body.exprs, plan.subplans, c.storage}
		}
	}

	return plan
}

fn columns_from_select(stmt SelectStmt, table Table, params map[string]Value, c &Connection) ?Columns {
	expr := stmt.exprs
	match expr {
		AsteriskExpr {
			return table.columns
		}
		[]DerivedColumn {
			mut columns := []Column{}
			for i, col in expr {
				mut column_name := 'COL${i + 1}'
				if col.as_clause.name != '' {
					column_name = col.as_clause.name
				} else if col.expr is Identifier {
					column_name = col.expr.name
				}
				empty_row := new_empty_row(table.columns)
				typ := eval_as_type(c, empty_row, col.expr, params) ?
				columns << Column{
					name: column_name
					typ: typ
				}
			}

			return columns
		}
	}
}

fn create_delete_plan(stmt DeleteStmt, params map[string]Value, c &Connection) ?Plan {
	select_stmt := SelectStmt{
		exprs: AsteriskExpr(true)
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
		exprs: AsteriskExpr(true)
		table_expression: TableExpression{
			from_clause: TablePrimary{
				body: new_identifier(stmt.table_name)
			}
			where_clause: stmt.where
		}
	}

	return create_select_plan(select_stmt, NoExpr{}, params, c, false)
}

fn create_query_expression_plan(stmt QueryExpression, params map[string]Value, c &Connection, correlation Correlation) ?Plan {
	mut plan := create_basic_plan(stmt.body, stmt.offset, params, c, true, correlation) ?

	if stmt.order.len > 0 {
		plan.operations << new_order_operation(stmt.order, params, c, plan.columns())
	}

	if stmt.fetch !is NoExpr || stmt.offset !is NoExpr {
		plan.operations << new_limit_operation(stmt.fetch, stmt.offset, params, c, plan.columns())
	}

	return plan
}

// The Plan itself is a PlanOperation. This allows more complex operations to be
// nested later.
struct Plan {
mut:
	operations []PlanOperation
	params     map[string]Value
	// subplans represent the subqueries. These are indexed by name and may be
	// referenced by expressions.
	subplans map[string]Plan
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

fn (p Plan) columns() Columns {
	// The columns at the end of the plan will always be whatever the last
	// operation returns.
	return p.operations[p.operations.len - 1].columns()
}

fn (p Plan) explain(elapsed_parse time.Duration) Result {
	mut rows := []Row{}

	for name, subplan in p.subplans {
		rows << new_row({
			'EXPLAIN': new_varchar_value(name + ':', 0)
		})
		rows << new_row({
			'EXPLAIN': new_varchar_value('  ' + subplan.str(), 0)
		})
	}

	for operation in p.operations {
		rows << new_row({
			'EXPLAIN': new_varchar_value(operation.str(), 0)
		})
	}

	return new_result([Column{'EXPLAIN', new_type('VARCHAR', 0), false}], rows, elapsed_parse,
		0)
}
