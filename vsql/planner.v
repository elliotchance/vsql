// planner.v contains the query planner which determines the best strategy for
// finding rows. The plan is built from a stack of operations, where each
// operation may take in rows but will always produce rows that can be fed into
// the next operation.

module vsql

import regex
import time

interface PlanOperation {
	str() string
	// A PlanOperation may return different columns from the input rows. This
	// will return the columns (including their types) from the result of this
	// operation. It's safe to invoke this before execute() and invokes multiple
	// times if needed.
	columns() Columns
mut:
	execute(row []Row) ![]Row
}

fn create_plan(stmt Stmt, params map[string]Value, mut conn Connection) !Plan {
	match stmt {
		DeleteStatementSearched {
			return create_delete_plan(stmt, params, mut conn)
		}
		QueryExpression {
			return create_query_expression_plan(stmt, params, mut conn, Correlation{})
		}
		UpdateStatementSearched {
			return create_update_plan(stmt, params, mut conn)
		}
		else {
			return error('cannot create plan for ${stmt}')
		}
	}
}

fn create_basic_plan(body SimpleTable, offset ?ValueSpecification, params map[string]Value, mut conn Connection, allow_virtual bool, correlation Correlation) !(Plan, map[string]Table) {
	match body {
		QuerySpecification {
			return create_select_plan(body, offset, params, mut conn, allow_virtual)
		}
		// VALUES
		[]RowValueConstructor {
			mut plan := Plan{}

			plan.operations << new_values_operation(body, new_integer_value(0), correlation, mut
				conn, params)!

			return plan, map[string]Table{}
		}
	}
}

fn create_select_plan(body QuerySpecification, offset ?ValueSpecification, params map[string]Value, mut conn Connection, allow_virtual bool) !(Plan, map[string]Table) {
	from_clause := body.table_expression.from_clause

	match from_clause {
		TablePrimary {
			plan, table := create_select_plan_without_join(body, from_clause, offset,
				params, mut conn, allow_virtual)!
			return plan, {
				table.name.id(): table
			}
		}
		QualifiedJoin {
			left_table_clause := from_clause.left_table as TablePrimary
			left_plan, left_table := create_select_plan_without_join(body, left_table_clause,
				offset, params, mut conn, allow_virtual)!

			right_table_clause := from_clause.right_table as TablePrimary
			right_plan, right_table := create_select_plan_without_join(body, right_table_clause,
				offset, params, mut conn, allow_virtual)!

			mut plan := Plan{}
			plan.subplans['\$1'] = left_plan
			plan.subplans['\$2'] = right_plan

			tables := {
				left_table.name.id():  left_table
				right_table.name.id(): right_table
			}

			plan.operations << new_join_operation(left_plan.columns(), from_clause.join_type,
				right_plan.columns(), from_clause.specification, params, conn, plan, tables)

			return plan, tables
		}
	}
}

fn create_select_plan_without_join(body QuerySpecification, from_clause TablePrimary, offset ?ValueSpecification, params map[string]Value, mut conn Connection, allow_virtual bool) !(Plan, Table) {
	mut plan := Plan{}
	mut covered_by_pk := false
	mut table := Table{}

	match from_clause.body {
		Identifier {
			mut table_name := conn.resolve_table_identifier(from_clause.body, allow_virtual)!
			table_name_id := table_name.storage_id()
			mut catalog := conn.catalogs[table_name.catalog_name] or {
				return error('unknown catalog: ${table_name.catalog_name}')
			}

			if allow_virtual && table_name_id in catalog.virtual_tables {
				plan.operations << VirtualTableOperation{table_name_id, catalog.virtual_tables[table_name_id]}
				table = catalog.virtual_tables[table_name_id].table()
			} else if table_name_id in catalog.storage.tables {
				table = catalog.storage.tables[table_name_id]

				// This is a special case to handle "PRIMARY KEY = INTEGER".
				if table.primary_key.len > 0 {
					if where := body.table_expression.where_clause {
						where_str := where.pstr(params)
						mut re := regex.regex_opt('^(\\w+) = (\\d+)$') or {
							return error('cannot compile regexp: ${err}')
						}
						if re.matches_string(where_str) {
							parts := where_str.split(' = ')
							if parts[0] == table.primary_key[0] {
								covered_by_pk = true
								plan.operations << new_primary_key_operation(table, new_numeric_value(parts[1]),
									new_numeric_value(parts[1]), params, conn)
							}
						}
					}
				}

				if !covered_by_pk {
					plan.operations << TableOperation{table_name, false, table, params, conn, plan.subplans}
				}

				if !covered_by_pk {
					if where := body.table_expression.where_clause {
						last_operation := plan.operations[plan.operations.len - 1]
						tables := {
							table.name.id(): table
						}
						plan.operations << new_where_operation(where, params, conn, last_operation.columns(),
							tables)
					}
				}
			} else {
				return sqlstate_42p01('table', table_name.str())
			}
		}
		QueryExpression {
			// TODO(elliotchance): Needs to increment.
			mut table_name := Identifier{
				custom_id: '\$1'
			}

			if from_clause.correlation.name.sub_entity_name != '' {
				table_name = from_clause.correlation.name
			}

			subplan := create_query_expression_plan(from_clause.body, params, mut conn,
				from_clause.correlation)!
			plan.subplans[table_name.id()] = subplan

			mut subplan_columns := []Column{}
			for col in subplan.columns() {
				subplan_columns << Column{Identifier{
					entity_name:     table_name.id()
					sub_entity_name: col.name.sub_entity_name
				}, col.typ, col.not_null}
			}

			// NOTE: This has to be assigned to a variable otherwise the value
			// is lost. This must be a bug in V.
			table = Table{
				name:    table_name
				columns: subplan_columns
			}

			plan.operations << TableOperation{table_name, true, table, params, conn, plan.subplans}
		}
	}

	// GROUP BY.
	//
	// TODO(elliotchance): This will break if trying to use GROUP BY on
	// "SELECT *".
	match body.exprs {
		[]DerivedColumn {
			tables := {
				table.name.id(): table
			}
			group_exprs := body.table_expression.group_clause
			mut select_exprs := []DerivedColumn{}
			for expr in body.exprs {
				select_exprs << DerivedColumn{expr.expr, expr.as_clause}
			}

			add_group_by_plan(mut &plan, group_exprs, select_exprs, params, mut conn,
				table, tables)!
		}
		AsteriskExpr, QualifiedAsteriskExpr {
			// It's not possible to have a GROUP BY in this case.
		}
	}

	return plan, table
}

fn add_group_by_plan(mut plan Plan, group_clause []Identifier, select_exprs []DerivedColumn, params map[string]Value, mut conn Connection, table Table, tables map[string]Table) ! {
	// There can be an explicit GROUP BY clause. However, if any of the
	// expressions contain an aggregate function we need to have an implicit
	// GROUP BY for the whole set.
	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}
	mut has_agg := false
	for e in select_exprs {
		if e.expr.compile(mut c)!.contains_agg {
			has_agg = true
			break
		}
	}

	if group_clause.len == 0 && !has_agg {
		return
	}

	mut order := []SortSpecification{}
	for col in group_clause {
		order << SortSpecification{
			expr:   ValueExpression(BooleanValueExpression{
				term: BooleanTerm{
					factor: BooleanTest{
						expr: BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(col)))
					}
				}
			})
			is_asc: true
		}
	}

	// We do not need to sort the set if the all rows belong to the same set.
	if group_clause.len > 0 {
		plan.operations << new_order_operation(order, params, conn, plan.columns())
	}

	plan.operations << new_group_operation(select_exprs, group_clause, params, mut conn,
		table)!
}

fn create_delete_plan(stmt DeleteStatementSearched, params map[string]Value, mut conn Connection) !Plan {
	select_stmt := QuerySpecification{
		exprs:            AsteriskExpr(true)
		table_expression: TableExpression{
			from_clause:  TablePrimary{
				body: stmt.table_name
			}
			where_clause: stmt.where
		}
	}

	plan, _ := create_select_plan(select_stmt, none, params, mut conn, false)!

	return plan
}

fn create_update_plan(stmt UpdateStatementSearched, params map[string]Value, mut conn Connection) !Plan {
	select_stmt := QuerySpecification{
		exprs:            AsteriskExpr(true)
		table_expression: TableExpression{
			from_clause:  TablePrimary{
				body: stmt.table_name
			}
			where_clause: stmt.where
		}
	}

	plan, _ := create_select_plan(select_stmt, none, params, mut conn, false)!

	return plan
}

fn create_query_expression_plan(stmt QueryExpression, params map[string]Value, mut conn Connection, correlation Correlation) !Plan {
	mut plan, tables := create_basic_plan(stmt.body, stmt.offset, params, mut conn, true,
		correlation)!

	if stmt.order.len > 0 {
		mut order := []SortSpecification{}
		for spec in stmt.order {
			order << SortSpecification{
				expr:   spec.expr
				is_asc: spec.is_asc
			}
		}

		plan.operations << new_order_operation(order, params, conn, plan.columns())
	}

	if stmt.fetch != none || stmt.offset != none {
		plan.operations << new_limit_operation(stmt.fetch, stmt.offset, params, mut conn,
			plan.columns())
	}

	if stmt.body is QuerySpecification {
		plan.operations << new_expr_operation(mut conn, params, stmt.body.exprs, tables)!
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

fn (mut o Plan) execute(_ []Row) ![]Row {
	mut rows := []Row{}
	for mut operation in o.operations {
		rows = operation.execute(rows)!
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
			'EXPLAIN': new_varchar_value(name + ':')
		})
		for line in subplan.str().split('\n') {
			rows << new_row({
				'EXPLAIN': new_varchar_value('  ' + line)
			})
		}
	}

	for operation in p.operations {
		rows << new_row({
			'EXPLAIN': new_varchar_value(operation.str())
		})
	}

	return new_result([
		Column{Identifier{ sub_entity_name: 'EXPLAIN' }, new_type('VARCHAR', 0, 0), false},
	], rows, elapsed_parse, 0)
}

// A ExprOperation executes expressions for each row.
struct ExprOperation {
mut:
	conn    &Connection
	params  map[string]Value
	exprs   []DerivedColumn
	columns []Column
	tables  map[string]Table
}

fn new_expr_operation(mut conn Connection, params map[string]Value, select_list SelectList, tables map[string]Table) !ExprOperation {
	mut exprs := []DerivedColumn{}
	mut columns := []Column{}

	match select_list {
		AsteriskExpr {
			for _, table in tables {
				columns << table.columns
				for column in table.columns {
					exprs << DerivedColumn{ValueExpression(CommonValueExpression(DatetimePrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(column.name))))), Identifier{
						sub_entity_name: column.name.sub_entity_name
					}}
				}
			}
		}
		QualifiedAsteriskExpr {
			mut table_name := conn.resolve_table_identifier(select_list.table_name, true)!
			table := tables[table_name.id()] or { return sqlstate_42p01('table', table_name.str()) }
			columns = table.columns
			for column in table.columns {
				exprs << DerivedColumn{ValueExpression(BooleanValueExpression{
					term: BooleanTerm{
						factor: BooleanTest{
							expr: BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(column.name)))
						}
					}
				}), Identifier{
					sub_entity_name: column.name.sub_entity_name
				}}
			}
		}
		[]DerivedColumn {
			for i, column in select_list {
				mut column_name := 'COL${i + 1}'
				if column.as_clause.sub_entity_name != '' {
					column_name = column.as_clause.sub_entity_name
				} else if column.expr is BooleanValueExpression {
					e := column.expr.term.factor.expr
					if e is BooleanPredicand {
						if e is NonparenthesizedValueExpressionPrimary {
							if e is Identifier {
								column_name = e.sub_entity_name
							}
						}
					}
				}

				expr := column.expr
				col := Identifier{
					sub_entity_name: column_name
				}
				mut c := Compiler{
					conn:   conn
					params: params
					tables: tables
				}

				columns << Column{col, expr.compile(mut c)!.typ, false}

				exprs << DerivedColumn{expr, col}
			}
		}
	}

	return ExprOperation{conn, params, exprs, columns, tables}
}

fn (o ExprOperation) str() string {
	return 'EXPR (${o.columns()})'
}

fn (o ExprOperation) columns() Columns {
	return o.columns
}

fn (mut o ExprOperation) execute(rows []Row) ![]Row {
	mut c := Compiler{
		conn:   o.conn
		params: o.params
		tables: o.tables
	}
	mut new_rows := []Row{}

	for row in rows {
		mut data := map[string]Value{}
		for expr in o.exprs {
			data[expr.as_clause.id()] = expr.expr.compile(mut c)!.run(mut o.conn, row,
				o.params)!
		}
		new_rows << new_row(data)
	}

	return new_rows
}
