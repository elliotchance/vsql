// planner.v contains the query planner which determines the best strategy for
// finding rows. The plan is built from a stack of operations, where each
// operation may take in rows but will always produce rows that can be fed into
// the next operation.

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
			return sqlstate_xx000('cannot create plan for ${stmt}')
		}
	}
}

fn create_basic_plan(body SimpleTable, params map[string]Value, mut conn Connection, allow_virtual bool, correlation Correlation) !(Plan, map[string]Table) {
	match body {
		QuerySpecification {
			return create_select_plan(body, params, mut conn, allow_virtual)
		}
		// VALUES
		[]RowValueConstructor {
			mut plan := Plan{}

			plan.operations << new_values_operation(body, correlation, mut
				conn, params)!

			return plan, map[string]Table{}
		}
		SetOperation {
			mut plan := Plan{}
			plan.subplans['\$1'] = create_query_expression_plan(*body.left, params, mut
				conn, Correlation{})!
			plan.subplans['\$2'] = create_query_expression_plan(*body.right, params, mut
				conn, Correlation{})!

			plan.operations << new_set_operation_operation(body, plan.subplans['\$1'],
				plan.subplans['\$2'], mut conn)!

			return plan, map[string]Table{}
		}
		ParenthesizedQueryExpression {
			return create_query_expression_plan(*body.expr, params, mut conn, correlation)!, map[string]Table{}
		}
	}
}

fn create_select_plan(body QuerySpecification, params map[string]Value, mut conn Connection, allow_virtual bool) !(Plan, map[string]Table) {
	from_clause := body.table_expression.from_clause

	mut plan := Plan{}
	mut tables := map[string]Table{}

	match from_clause {
		TablePrimary {
			table_plan, table := create_select_plan_without_join(body, from_clause,
				params, mut conn, allow_virtual, true)!
			plan = table_plan
			tables[table.name.id()] = table
		}
		QualifiedJoin {
			plan = create_join_plan(body, from_clause, params, mut conn, allow_virtual, mut
				tables)!

			// The WHERE clause applies to the joined rows, so it can't be used to
			// filter either side before the join.
			add_where_plan(mut &plan, body, params, conn, tables)!
		}
	}

	// GROUP BY. An asterisk is the same as listing every column, so each one must
	// be a grouping column.
	mut select_exprs := []DerivedColumn{}
	match body.exprs {
		[]SelectSublist {
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
		}
		AsteriskExpr {
			for _, table in tables {
				for column in table.columns {
					select_exprs << column_derived_column(column)
				}
			}
		}
	}

	add_group_by_plan(mut &plan, body.table_expression.group_clause, body.table_expression.having_clause,
		select_exprs, params, mut conn, tables)!

	if body.distinct {
		plan.operations << new_distinct_operation(mut conn, params, body.exprs, tables,
			plan.columns())!
	}

	return plan, tables
}

// create_join_plan joins two table references. Either side may itself be a
// join, such as "t1 LEFT JOIN t2 ON ... LEFT JOIN t3 ON ...". Each table used is
// added to tables.
fn create_join_plan(body QuerySpecification, join QualifiedJoin, params map[string]Value, mut conn Connection, allow_virtual bool, mut tables map[string]Table) !Plan {
	mut plan := Plan{}
	plan.subplans['\$1'] = create_table_reference_plan(body, join.left_table,
		params, mut conn, allow_virtual, mut tables)!
	plan.subplans['\$2'] = create_table_reference_plan(body, join.right_table,
		params, mut conn, allow_virtual, mut tables)!

	// Like WHERE, the condition is compiled to catch errors without any rows.
	mut c := Compiler{
		conn:                   conn
		params:                 params
		tables:                 tables
		next_value_not_allowed: 'a join condition'
	}
	join.specification.compile(mut c)!

	plan.operations << new_join_operation(plan.subplans['\$1'].columns(), join.join_type,
		plan.subplans['\$2'].columns(), join.specification, params, conn, plan, tables.clone())

	return plan
}

fn create_table_reference_plan(body QuerySpecification, table_reference TableReference, params map[string]Value, mut conn Connection, allow_virtual bool, mut tables map[string]Table) !Plan {
	match table_reference {
		TablePrimary {
			plan, table := create_select_plan_without_join(body, table_reference,
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
			return create_join_plan(body, table_reference, params, mut conn,
				allow_virtual, mut tables)
		}
	}
}

// create_select_plan_without_join reads the rows of one table. The WHERE clause
// is only applied (and used to choose a primary key lookup) with filter, when
// the table is the whole FROM clause.
fn create_select_plan_without_join(body QuerySpecification, from_clause TablePrimary, params map[string]Value, mut conn Connection, allow_virtual bool, filter bool) !(Plan, Table) {
	mut plan := Plan{}
	mut covered_by_pk := false
	mut table := Table{}

	match from_clause.body {
		Identifier {
			// A table with a correlation name, such as "t AS x (c1, c2)", is
			// read like a derived table so that its rows use the new names.
			if from_clause.correlation.name.sub_entity_name != '' {
				subplan, base_table := create_select_plan_without_join(body, TablePrimary{
					body: from_clause.body
				}, params, mut conn, allow_virtual, false)!
				table = add_correlation_plan(mut &plan, from_clause.correlation.name,
					subplan, from_clause.correlation, params, conn)!

				// The primary key can only be found once the columns have their
				// new names, then the table is read again with the lookup.
				if filter {
					if value := primary_key_value(body, base_table, table, params, conn) {
						plan = Plan{}
						table = add_correlation_plan(mut &plan, from_clause.correlation.name,
							Plan{
								operations: [
									new_primary_key_operation(base_table, value, value, params,
										conn),
								]
							}, from_clause.correlation, params, conn)!

						return plan, table
					}

					add_where_plan(mut &plan, body, params, conn, {
						table.name.id(): table
					})!
				}

				return plan, table
			}

			mut table_name := conn.resolve_table_identifier(from_clause.body, allow_virtual)!
			table_name_id := table_name.storage_id()
			mut catalog := conn.catalogs[table_name.catalog_name] or {
				return sqlstate_3d000(table_name.catalog_name)
			}

			if allow_virtual && table_name_id in catalog.virtual_tables {
				plan.operations << VirtualTableOperation{table_name_id, catalog.virtual_tables[table_name_id], conn}
				table = catalog.virtual_tables[table_name_id].table()
				if filter {
					add_where_plan(mut &plan, body, params, conn, {
						table.name.id(): table
					})!
				}
			} else if table_name_id in catalog.storage.tables {
				table = catalog.storage.table(table_name_id)

				if filter {
					if value := primary_key_value(body, table, table, params, conn) {
						covered_by_pk = true
						plan.operations << new_primary_key_operation(table, value, value,
							params, conn)
					}
				}

				if !covered_by_pk {
					plan.operations << TableOperation{table_name, false, table, params, conn, plan.subplans}
				}

				if !covered_by_pk {
					if filter {
						add_where_plan(mut &plan, body, params, conn, {
							table.name.id(): table
						})!
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
			table = add_correlation_plan(mut &plan, table_name, subplan, from_clause.correlation,
				params, conn)!

			if filter {
				add_where_plan(mut &plan, body, params, conn, {
					table.name.id(): table
				})!
			}
		}
	}

	return plan, table
}

// primary_key_value is the integer that the WHERE clause compares the primary
// key to, if the WHERE clause is only "column = integer" (in either order) and
// the primary key is that one integer column. The rows can then be found with
// the primary key instead of reading the whole table.
//
// base_table is the stored table and table is how the query names it, which is
// different with a correlation name, such as "t AS x (a, b)".
fn primary_key_value(body QuerySpecification, base_table Table, table Table, params map[string]Value, conn &Connection) ?Value {
	if base_table.primary_key.len != 1 {
		return none
	}

	mut pk_index := 0
	for base_table.columns[pk_index].name.sub_entity_name != base_table.primary_key[0] {
		pk_index++
	}
	if base_table.columns[pk_index].typ.typ !in [.is_smallint, .is_integer, .is_bigint] {
		return none
	}

	where := body.table_expression.where_clause or { return none }
	if _ := where.expr {
		return none
	}
	if _ := where.term.term {
		return none
	}
	test := where.term.factor
	if _ := test.value {
		return none
	}
	if test.inverse {
		return none
	}

	primary := *test.expr
	comparison := match primary {
		Predicate {
			match primary {
				ComparisonPredicate { primary }
				else { return none }
			}
		}
		else {
			return none
		}
	}
	if comparison.op != .equal {
		return none
	}

	pk_column := table.columns[pk_index].name.sub_entity_name
	for sides in [[comparison.left, comparison.right], [comparison.right, comparison.left]] {
		column := new_column_identifier(sides[0].pstr(params)) or { continue }
		value := sides[1].pstr(params)
		if column.custom_id == '' && column.sub_entity_name == pk_column
			&& column.is_column_of_table(conn, table) && value != ''
			&& value.bytes().all(it.is_digit()) {
			return new_numeric_value(value)
		}
	}

	return none
}

// add_correlation_plan reads the rows of subplan as the table table_name. A
// derived column list in the correlation renames the columns.
fn add_correlation_plan(mut plan Plan, table_name Identifier, subplan Plan, correlation Correlation, params map[string]Value, conn &Connection) !Table {
	plan.subplans[table_name.id()] = subplan

	correlation_columns := correlation.columns
	if correlation_columns.len > 0 && correlation_columns.len != subplan.columns().len {
		return sqlstate_42601('ROW provides the wrong number of columns for the correlation')
	}

	// ISO/IEC 9075-2:2016(E), 7.6, <table reference>, Syntax Rule 11b
	mut seen := map[string]bool{}
	for column in correlation_columns {
		if column.sub_entity_name in seen {
			return sqlstate_42601('column ${column.sub_entity_name} is specified more than once')
		}
		seen[column.sub_entity_name] = true
	}

	mut columns := []Column{}
	for i, col in subplan.columns() {
		columns << Column{Identifier{
			entity_name:     table_name.id()
			sub_entity_name: if correlation_columns.len > 0 {
				correlation_columns[i].sub_entity_name
			} else {
				col.name.sub_entity_name
			}
		}, col.typ, col.not_null, none}
	}

	// NOTE: This has to be assigned to a variable otherwise the value is lost.
	// This must be a bug in V.
	table := Table{
		name:    table_name
		columns: columns
	}

	plan.operations << TableOperation{table_name, true, table, params, conn, plan.subplans}

	return table
}

// add_where_plan filters the rows of the last operation with the WHERE clause,
// if there is one. The condition is only evaluated for each row, so it's
// compiled here to catch errors even when there are no rows.
fn add_where_plan(mut plan Plan, body QuerySpecification, params map[string]Value, conn &Connection, tables map[string]Table) ! {
	if where := body.table_expression.where_clause {
		mut c := Compiler{
			conn:                   conn
			params:                 params
			tables:                 tables
			next_value_not_allowed: 'WHERE'
		}
		where.compile(mut c)!

		last_operation := plan.operations[plan.operations.len - 1]
		plan.operations << new_where_operation(where, params, conn, last_operation.columns(),
			tables)
	}
}

fn add_group_by_plan(mut plan Plan, group_clause []Identifier, having_clause ?BooleanValueExpression, select_exprs []DerivedColumn, params map[string]Value, mut conn Connection, tables map[string]Table) ! {
	// There can be an explicit GROUP BY clause. However, if any of the
	// expressions contain an aggregate function (or there is a HAVING) we need to
	// have an implicit GROUP BY for the whole set.
	//
	// ISO/IEC 9075-2:2016(E), 7.14, <having clause>, Syntax Rules, 1
	mut c := Compiler{
		conn:   conn
		params: params
		tables: tables
	}
	mut has_agg := having_clause != none
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

	// The HAVING has the same rule (7.14, Syntax Rules, 2) and must be a boolean.
	if having := having_clause {
		c.next_value_not_allowed = 'HAVING'
		compiled_having := having.compile(mut c)!
		if compiled_having.typ.typ != .is_boolean {
			return sqlstate_42804('in HAVING', 'BOOLEAN', compiled_having.typ.str())
		}
	}

	mut order := []SortSpecification{}
	for col in group_clause {
		order << SortSpecification{
			expr:   ValueExpression(BooleanValueExpression{
				term: BooleanTerm{
					factor: new_boolean_test(BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(col))),
						false, none, false)
				}
			})
			is_asc: true
		}
	}

	// We do not need to sort the set if the all rows belong to the same set.
	if group_clause.len > 0 {
		plan.operations << new_order_operation(order, params, conn, plan.columns(), tables)
	}

	plan.operations << new_group_operation(select_exprs, group_clause, having_clause,
		params, mut conn, tables)!

	if having := having_clause {
		plan.operations << new_where_operation(having, params, conn, plan.columns(),
			tables)
	}
}

fn create_delete_plan(stmt DeleteStatementSearched, params map[string]Value, mut conn Connection) !Plan {
	select_stmt := QuerySpecification{
		exprs:            AsteriskExpr(true)
		table_expression: &TableExpression{
			from_clause:  TablePrimary{
				body: stmt.table_name
			}
			where_clause: stmt.where
		}
	}

	plan, _ := create_select_plan(select_stmt, params, mut conn, false)!

	return plan
}

fn create_update_plan(stmt UpdateStatementSearched, params map[string]Value, mut conn Connection) !Plan {
	select_stmt := QuerySpecification{
		exprs:            AsteriskExpr(true)
		table_expression: &TableExpression{
			from_clause:  TablePrimary{
				body: stmt.table_name
			}
			where_clause: stmt.where
		}
	}

	plan, _ := create_select_plan(select_stmt, params, mut conn, false)!

	return plan
}

fn create_query_expression_plan(stmt QueryExpression, params map[string]Value, mut conn Connection, correlation Correlation) !Plan {
	mut plan, mut tables := create_basic_plan(stmt.body, params, mut conn, true,
		correlation)!

	// Only a query specification has its own tables. Otherwise, the ORDER BY can
	// only use the columns of the result (7.17, Syntax Rule 28d).
	if stmt.body !is QuerySpecification {
		tables = {
			'': Table{
				columns: plan.columns()
			}
		}
	}

	if stmt.order.len > 0 {
		// The expressions are only evaluated when rows are compared, so they're
		// compiled here to catch errors (such as an ambiguous column) even when
		// there are no rows.
		mut c := Compiler{
			conn:                   conn
			params:                 params
			tables:                 tables
			next_value_not_allowed: 'ORDER BY'
		}
		mut order := []SortSpecification{}
		for spec in stmt.order {
			c.set_distinct_columns(stmt.body, spec.expr)!
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
		Column{Identifier{ sub_entity_name: 'EXPLAIN' }, new_type('VARCHAR', 0, 0), false, none},
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
						} else if column := item.column_reference() {
							column_name = column.sub_entity_name
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

						columns << Column{col, expr.compile(mut c)!.typ, false, none}

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
			}, columns[i].typ, columns[i].not_null, none}
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
			factor: new_boolean_test(BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(column.name))),
				false, none, false)
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
