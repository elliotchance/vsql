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

	mut plan := Plan{}
	mut tables := map[string]Table{}

	match from_clause {
		TablePrimary {
			table_plan, table := create_select_plan_without_join(body, from_clause, offset,
				params, mut conn, allow_virtual, true)!
			plan = table_plan
			tables[table.name.id()] = table
		}
		QualifiedJoin {
			plan = create_join_plan(body, from_clause, offset, params, mut conn, allow_virtual, mut
				tables)!

			// The WHERE clause applies to the joined rows, so it can't be used to
			// filter either side before the join.
			add_where_plan(mut &plan, body, params, conn, tables)
		}
	}

	// GROUP BY.
	//
	// TODO(elliotchance): This will break if trying to use GROUP BY on
	// "SELECT *".
	match body.exprs {
		[]SelectSublist {
			group_exprs := body.table_expression.group_clause
			mut select_exprs := []DerivedColumn{}
			for item in body.exprs {
				match item {
					DerivedColumn {
						select_exprs << item
					}
					QualifiedAsteriskExpr {
						table := qualified_asterisk_table(item, mut conn, tables)!
						for column in table.columns {
							select_exprs << column_derived_column(column)
						}
					}
				}
			}

			add_group_by_plan(mut &plan, group_exprs, select_exprs, params, mut conn,
				tables)!
		}
		AsteriskExpr {
			// It's not possible to have a GROUP BY in this case.
		}
	}

	return plan, tables
}

// create_join_plan joins two table references. Either side may itself be a
// join, such as "t1 LEFT JOIN t2 ON ... LEFT JOIN t3 ON ...". Each table used is
// added to tables.
fn create_join_plan(body QuerySpecification, join QualifiedJoin, offset ?ValueSpecification, params map[string]Value, mut conn Connection, allow_virtual bool, mut tables map[string]Table) !Plan {
	mut plan := Plan{}
	plan.subplans['\$1'] = create_table_reference_plan(body, join.left_table, offset,
		params, mut conn, allow_virtual, mut tables)!
	plan.subplans['\$2'] = create_table_reference_plan(body, join.right_table, offset,
		params, mut conn, allow_virtual, mut tables)!

	plan.operations << new_join_operation(plan.subplans['\$1'].columns(), join.join_type,
		plan.subplans['\$2'].columns(), join.specification, params, conn, plan, tables.clone())

	return plan
}

fn create_table_reference_plan(body QuerySpecification, table_reference TableReference, offset ?ValueSpecification, params map[string]Value, mut conn Connection, allow_virtual bool, mut tables map[string]Table) !Plan {
	match table_reference {
		TablePrimary {
			plan, table := create_select_plan_without_join(body, table_reference, offset,
				params, mut conn, allow_virtual, false)!

			// Rows store each value by its table and column name, so the same
			// table can't be used twice (7.5, Syntax Rule 5c).
			if table.name.id() in tables {
				// Subqueries without a correlation name all use the same name.
				if table.name.custom_id != '' {
					return sqlstate_42601('each subquery in FROM needs its own correlation name')
				}

				return sqlstate_42601('table name ${table.name} specified more than once')
			}
			tables[table.name.id()] = table

			return plan
		}
		QualifiedJoin {
			return create_join_plan(body, table_reference, offset, params, mut conn,
				allow_virtual, mut tables)
		}
	}
}

// create_select_plan_without_join reads the rows of one table. The WHERE clause
// is only applied (and used to choose a primary key lookup) with filter, when
// the table is the whole FROM clause.
fn create_select_plan_without_join(body QuerySpecification, from_clause TablePrimary, offset ?ValueSpecification, params map[string]Value, mut conn Connection, allow_virtual bool, filter bool) !(Plan, Table) {
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
				if filter {
					add_where_plan(mut &plan, body, params, conn, {
						table.name.id(): table
					})
				}
			} else if table_name_id in catalog.storage.tables {
				table = catalog.storage.tables[table_name_id]

				// This is a special case to handle "PRIMARY KEY = INTEGER". It only
				// applies to a PRIMARY KEY with one column.
				if filter && table.primary_key.len == 1 {
					if where := body.table_expression.where_clause {
						where_str := where.pstr(params)
						mut re := regex.regex_opt('^(\\w+) = (\\d+)$') or {
							return error('cannot compile regexp: ${err}')
						}
						if re.matches_string(where_str) {
							parts := where_str.split(' = ')
							if parts[0] == table.primary_key[0] {
								covered_by_pk = true
								plan.operations << new_primary_key_operation(table,
									new_numeric_value(parts[1]), new_numeric_value(parts[1]),
									params, conn)
							}
						}
					}
				}

				if !covered_by_pk {
					plan.operations << TableOperation{table_name, false, table, params, conn, plan.subplans}
				}

				if !covered_by_pk {
					if filter {
						add_where_plan(mut &plan, body, params, conn, {
							table.name.id(): table
						})
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

			// A derived column list renames the columns of the subquery.
			correlation_columns := from_clause.correlation.columns
			if correlation_columns.len > 0 && correlation_columns.len != subplan.columns().len {
				return sqlstate_42601('ROW provides the wrong number of columns for the correlation')
			}

			mut subplan_columns := []Column{}
			for i, col in subplan.columns() {
				subplan_columns << Column{Identifier{
					entity_name:     table_name.id()
					sub_entity_name: if correlation_columns.len > 0 {
						correlation_columns[i].sub_entity_name
					} else {
						col.name.sub_entity_name
					}
				}, col.typ, col.not_null}
			}

			// NOTE: This has to be assigned to a variable otherwise the value
			// is lost. This must be a bug in V.
			table = Table{
				name:    table_name
				columns: subplan_columns
			}

			plan.operations << TableOperation{table_name, true, table, params, conn, plan.subplans}
			if filter {
				add_where_plan(mut &plan, body, params, conn, {
					table.name.id(): table
				})
			}
		}
	}

	return plan, table
}

// add_where_plan filters the rows of the last operation with the WHERE clause,
// if there is one.
fn add_where_plan(mut plan Plan, body QuerySpecification, params map[string]Value, conn &Connection, tables map[string]Table) {
	if where := body.table_expression.where_clause {
		last_operation := plan.operations[plan.operations.len - 1]
		plan.operations << new_where_operation(where, params, conn, last_operation.columns(),
			tables)
	}
}

fn add_group_by_plan(mut plan Plan, group_clause []Identifier, select_exprs []DerivedColumn, params map[string]Value, mut conn Connection, tables map[string]Table) ! {
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

	// Every column in the select list must be grouped, or only used in an
	// aggregate function.
	mut grouping_columns := []Column{}
	for col in group_clause {
		grouping_columns << group_column(col, tables)!
	}
	c.grouping_columns = grouping_columns
	for e in select_exprs {
		e.expr.compile(mut c)!
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
		plan.operations << new_order_operation(order, params, conn, plan.columns(), tables)
	}

	plan.operations << new_group_operation(select_exprs, group_clause, params, mut conn, tables)!
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
		// The expressions are only evaluated when rows are compared, so they're
		// compiled here to catch errors (such as an ambiguous column) even when
		// there are no rows.
		mut c := Compiler{
			conn:   conn
			params: params
			tables: tables
		}
		mut order := []SortSpecification{}
		for spec in stmt.order {
			spec.expr.compile(mut c)!
			order << SortSpecification{
				expr:   spec.expr
				is_asc: spec.is_asc
			}
		}

		plan.operations << new_order_operation(order, params, conn, plan.columns(), tables)
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
	for line in p.explain_lines() {
		rows << new_row({
			'EXPLAIN': new_varchar_value(line)
		})
	}

	return new_result([
		Column{Identifier{ sub_entity_name: 'EXPLAIN' }, new_type('VARCHAR', 0, 0), false},
	], rows, elapsed_parse, 0)
}

// explain_lines lists the subplans (indented under their names) followed by the
// operations. Subplans of a join can also be joins, so this is recursive.
fn (p Plan) explain_lines() []string {
	mut lines := []string{}

	for name, subplan in p.subplans {
		lines << name + ':'
		for line in subplan.explain_lines() {
			lines << '  ' + line
		}
	}

	for operation in p.operations {
		lines << operation.str()
	}

	return lines
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
		[]SelectSublist {
			for item in select_list {
				match item {
					QualifiedAsteriskExpr {
						table := qualified_asterisk_table(item, mut conn, tables)!
						columns << table.columns
						for column in table.columns {
							exprs << column_derived_column(column)
						}
					}
					DerivedColumn {
						// Unnamed columns are named by their position in the result.
						mut column_name := 'COL${columns.len + 1}'
						if item.as_clause.sub_entity_name != '' {
							column_name = item.as_clause.sub_entity_name
						} else if item.expr is BooleanValueExpression {
							e := item.expr.term.factor.expr
							if e is BooleanPredicand {
								if e is NonparenthesizedValueExpressionPrimary {
									if e is Identifier {
										column_name = e.sub_entity_name
									}
								}
							}
						}

						expr := item.expr
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
		}
	}

	// A result can have more than one column with the same name, such as a.id
	// and b.id (7.16). Each one after the first is kept in the row under a
	// different key, see Row.get_column.
	mut seen := map[string]int{}
	for i, expr in exprs {
		name := expr.as_clause.id()
		seen[name]++
		if seen[name] > 1 {
			key := '${name}\x00${seen[name]}'
			exprs[i] = DerivedColumn{expr.expr, Identifier{
				custom_id:       key
				sub_entity_name: expr.as_clause.sub_entity_name
			}}
			columns[i] = Column{Identifier{
				...columns[i].name
				custom_id: key
			}, columns[i].typ, columns[i].not_null}
		}
	}

	return ExprOperation{conn, params, exprs, columns, tables}
}

// qualified_asterisk_table returns the table that "t.*" refers to.
fn qualified_asterisk_table(e QualifiedAsteriskExpr, mut conn Connection, tables map[string]Table) !Table {
	// A derived table, such as "(SELECT ...) AS t", is only known by its
	// correlation name.
	if e.table_name.schema_name == '' {
		if table := tables[e.table_name.entity_name] {
			return table
		}
	}

	table_name := conn.resolve_table_identifier(e.table_name, true)!

	// A table loaded from the file doesn't have the catalog in its name (see
	// new_table_from_bytes).
	for _, table in tables {
		if table.name.schema_name == table_name.schema_name
			&& table.name.entity_name == table_name.entity_name
			&& table.name.catalog_name in ['', table_name.catalog_name] {
			return table
		}
	}

	return sqlstate_42p01('table', table_name.str())
}

// column_derived_column is the select list item for one column of "t.*".
fn column_derived_column(column Column) DerivedColumn {
	return DerivedColumn{ValueExpression(BooleanValueExpression{
		term: BooleanTerm{
			factor: BooleanTest{
				expr: BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(column.name)))
			}
		}
	}), Identifier{
		sub_entity_name: column.name.sub_entity_name
	}}
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
		o.conn.begin_row()
		mut data := map[string]Value{}
		for expr in o.exprs {
			data[expr.as_clause.id()] = expr.expr.compile(mut c)!.run(mut o.conn, row, o.params)!
		}
		new_rows << new_row(data)
	}

	return new_rows
}
