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

fn create_basic_plan(body SimpleTable, params map[string]Value, mut conn Connection, allow_virtual bool, correlation Correlation) !(Plan, map[string]&Table) {
	match body {
		QuerySpecification {
			return create_select_plan(body, params, mut conn, allow_virtual)
		}
		// VALUES
		[]RowValueConstructor {
			mut plan := Plan{}

			plan.operations << new_values_operation(body, correlation, mut
				conn, params)!

			return plan, map[string]&Table{}
		}
		SetOperation {
			// Only a query specification that's the whole query can contain a
			// NEXT VALUE FOR, not one on either side of a UNION, EXCEPT or
			// INTERSECT.
			//
			// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 1
			next_value_not_allowed := conn.next_value_not_allowed
			if next_value_not_allowed == '' {
				conn.next_value_not_allowed = body.op
			}
			defer {
				conn.next_value_not_allowed = next_value_not_allowed
			}

			mut plan := Plan{}
			plan.subplans['\$1'] = create_query_expression_plan(*body.left, params, mut
				conn, Correlation{})!
			plan.subplans['\$2'] = create_query_expression_plan(*body.right, params, mut
				conn, Correlation{})!

			plan.operations << new_set_operation_operation(body, plan.subplans['\$1'] or { Plan{} },
				plan.subplans['\$2'] or { Plan{} }, mut conn)!

			return plan, map[string]&Table{}
		}
		ParenthesizedQueryExpression {
			return create_query_expression_plan(*body.expr, params, mut conn, correlation)!, map[string]&Table{}
		}
	}
}

fn create_select_plan(body QuerySpecification, params map[string]Value, mut conn Connection, allow_virtual bool) !(Plan, map[string]&Table) {
	from_clause := body.table_expression.from_clause

	mut plan := Plan{}
	mut tables := map[string]&Table{}

	match from_clause {
		TablePrimary {
			if body.without_from {
				// The table is in scope, even though it has no columns, so that a
				// column reference is an unknown column.
				table := Table{
					name: Identifier{
						custom_id: '\$1'
					}
				}
				plan.operations << &SingleRowOperation{}
				tables[table.name.id()] = &Table{
					...table
				}
			} else {
				table_plan, table := create_select_plan_without_join(body, from_clause,
					params, mut conn, allow_virtual, true)!
				plan = table_plan
				tables[table.name.id()] = &Table{
					...table
					columns: table.result_columns()
				}
			}
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
//
// The join condition can only see the tables of this join. Others in FROM aren't
// in scope, such as t1 in "FROM t1, t2 JOIN t3 ON ...".
//
// ISO/IEC 9075-2:2016(E), 7.5, <from clause>, Syntax Rules, 2
fn create_join_plan(body QuerySpecification, join QualifiedJoin, params map[string]Value, mut conn Connection, allow_virtual bool, mut tables map[string]&Table) !Plan {
	outside_join := tables.keys()

	mut plan := Plan{}
	before_left := tables.keys()
	first_table := tables.len
	plan.subplans['\$1'] = create_table_reference_plan(body, join.left_table,
		params, mut conn, allow_virtual, mut tables)!
	before_right := tables.keys()
	plan.subplans['\$2'] = create_table_reference_plan(body, join.right_table,
		params, mut conn, allow_virtual, mut tables)!
	left_columns := (plan.subplans['\$1'] or { Plan{} }).columns()
	right_columns := (plan.subplans['\$2'] or { Plan{} }).columns()

	range_variable := '\$USING${tables.len}'
	mut common_columns := []CommonColumn{}
	specification := match join.specification {
		BooleanValueExpression {
			join.specification
		}
		[]Identifier {
			common_columns = new_common_columns(join.specification, join.join_type, left_columns,
				right_columns, range_variable)!
			join_equalities(common_columns)
		}
	}

	mut join_tables := tables.clone()
	for name in outside_join {
		join_tables.delete(name)
	}

	// Like WHERE, the condition is compiled to catch errors without any rows. An
	// aggregate function of an outer query (which is a value here) is allowed.
	//
	// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 6
	// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 7
	mut c := Compiler{
		conn:                   conn
		params:                 params
		tables:                 join_tables
		next_value_not_allowed: 'a join condition'
	}
	if specification.compile(mut c)!.contains_agg {
		return sqlstate_42601('an aggregate function cannot be used in a join condition')
	}

	left_names := before_right.filter(it !in before_left)
	right_names := tables.keys().filter(it !in before_right)
	lookup := if join.join_type == .right {
		join_lookup(join.left_table, left_names, right_names, specification, tables,
			params, mut conn, allow_virtual)
	} else {
		join_lookup(join.right_table, right_names, left_names, specification, tables,
			params, mut conn, allow_virtual)
	}
	if l := lookup {
		// EXPLAIN shows the lookup instead of reading the whole table.
		inner := if join.join_type == .right { '\$1' } else { '\$2' }
		mut inner_plan := plan.subplans[inner] or { Plan{} }
		if l.table.name.id() == l.base_table.name.id() {
			inner_plan.operations[0] = l.operation
		} else {
			inner_plan.subplans[l.table.name.id()] = Plan{
				operations: [l.operation]
			}
		}
		plan.subplans[inner] = inner_plan
	}

	// The tables on the side that isn't preserved can be all NULLs, whatever
	// their columns are declared as.
	null_extended := match join.join_type {
		.inner { []string{} }
		.left { tables.keys().filter(it !in before_right) }
		.right { before_right.filter(it !in before_left) }
	}
	for name, table in tables.clone() {
		if name in null_extended {
			tables[name] = &Table{
				...table
				columns: possibly_nullable_columns(table.columns)
			}
		}
	}

	plan.operations << new_join_operation(left_columns, join.join_type, right_columns,
		specification, common_columns, params, conn, plan, join_tables, lookup)

	if common_columns.len > 0 {
		tables = add_common_columns_range_variable(tables, first_table, range_variable,
			common_columns)
	}

	return plan
}

// join_lookup finds the rows of the inner side of a join (inner_reference) for
// each row of the outer side, when it's a table that has an index (or PRIMARY
// KEY) that the join condition can use, such as an index on y for
// "t1 JOIN t2 ON t2.y = t1.x" (see best_key_operation). The values that the
// columns of the index are compared with can only use the columns of the outer
// side (the tables named in outer_names), the inner side is named in
// inner_names. It's none when there isn't one, such as when the inner side is a
// derived table or another join.
fn join_lookup(inner_reference TableReference, inner_names []string, outer_names []string, specification BooleanValueExpression, tables map[string]&Table, params map[string]Value, mut conn Connection, allow_virtual bool) ?JoinLookup {
	inner := match inner_reference {
		TablePrimary { inner_reference }
		QualifiedJoin { return none }
	}
	name := match inner.body {
		Identifier { inner.body }
		QueryExpression { return none }
	}

	inner_name := conn.resolve_table_identifier(name, allow_virtual) or { return none }
	table_name_id := inner_name.storage_id()
	mut catalog := conn.catalogs[inner_name.catalog_name] or { return none }
	if (allow_virtual && table_name_id in catalog.virtual_tables)
		|| table_name_id !in catalog.storage.tables {
		return none
	}

	mut value_tables := map[string]&Table{}
	for table_name, outer_table in tables {
		if table_name in outer_names {
			value_tables[table_name] = outer_table
		}
	}
	base_table := catalog.storage.table(table_name_id)
	table := tables[inner_names[0]] or { return none }
	operation := best_key_operation(and_factors(specification), base_table, table,
		value_tables, params, mut conn)?

	return JoinLookup{base_table, table, operation}
}

// add_common_columns_range_variable moves the common columns out of the range
// variables of both sides of a named columns join and into a new range variable
// with an implementation-dependent name. So only an unqualified name can
// reference a common column, and "t.*" doesn't include it. The new range variable
// goes before the tables of the join (from first_table) because its columns are
// first in "SELECT *".
//
// ISO/IEC 9075-2:2016(E), 7.10, <joined table>, Syntax Rules, 10.a.ii, 10.f.iv and 11.a.i
fn add_common_columns_range_variable(tables map[string]&Table, first_table int, range_variable string, common_columns []CommonColumn) map[string]&Table {
	mut hidden := map[string]bool{}
	for common in common_columns {
		hidden[common.left.name.id()] = true
		hidden[common.right.name.id()] = true
	}

	mut new_tables := map[string]&Table{}
	mut i := 0
	for name, table in tables {
		if i == first_table {
			new_tables[range_variable] = &Table{
				name:    Identifier{
					custom_id: range_variable
				}
				columns: common_columns.map(it.column)
			}
		}
		new_tables[name] = &Table{
			...table
			columns: table.columns.filter(it.name.id() !in hidden)
		}
		i++
	}

	return new_tables
}

fn create_table_reference_plan(body QuerySpecification, table_reference TableReference, params map[string]Value, mut conn Connection, allow_virtual bool, mut tables map[string]&Table) !Plan {
	match table_reference {
		TablePrimary {
			plan, table := create_select_plan_without_join(body, table_reference,
				params, mut conn, allow_virtual, false)!

			// Rows store each value by its table and column name, so the same
			// table can't be used twice. A correlation name also can't be the
			// unqualified name of another table.
			//
			// ISO/IEC 9075-2:2016(E), 7.5, <from clause>, Syntax Rules, 5.c
			if table.name.id() in tables {
				// Subqueries without a correlation name all use the same name.
				if table.name.custom_id != '' {
					return sqlstate_42601('each subquery in FROM needs its own correlation name')
				}

				return sqlstate_42601('table name ${table.name} specified more than once')
			}
			for _, other in tables {
				if is_same_range_variable(table.name, other.name) {
					return sqlstate_42601('table name ${unqualified_range_variable(table.name)} specified more than once')
				}
			}
			tables[table.name.id()] = &Table{
				...table
				columns: table.result_columns()
			}

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
					subplan, from_clause.correlation, params, mut conn)!

				// The primary key can only be found once the columns have their
				// new names, then the table is read again with the lookup.
				if filter {
					if operation := key_operation(body, base_table, table, params, mut conn) {
						plan = Plan{}
						table = add_correlation_plan(mut &plan, from_clause.correlation.name,
							Plan{
								operations: [operation]
							}, from_clause.correlation, params, mut conn)!
					}

					add_where_plan(mut &plan, body, params, conn, {
						table.name.id(): &Table{
							...table
						}
					})!
				}

				return plan, table
			}

			mut table_name := conn.resolve_table_identifier(from_clause.body, allow_virtual)!
			table_name_id := table_name.storage_id()
			mut catalog := conn.catalogs[table_name.catalog_name] or {
				return sqlstate_3d000(table_name.catalog_name)
			}

			if conn.collect_subquery_tables && conn.subquery_scopes.len > 0 {
				conn.subquery_tables << table_name.id()
			}

			if allow_virtual && table_name_id in catalog.virtual_tables {
				// The table is known to be there.
				virtual_table := unsafe { catalog.virtual_tables[table_name_id] }
				plan.operations << VirtualTableOperation{table_name_id, virtual_table, conn}
				table = virtual_table.table()
				if filter {
					add_where_plan(mut &plan, body, params, conn, {
						table.name.id(): &Table{
							...table
						}
					})!
				}
			} else if table_name_id in catalog.storage.tables {
				table = catalog.storage.table(table_name_id)
				conn.flag_subquery_table(table_name)

				mut operation := PlanOperation(TableOperation{table_name, false, table, params, conn, plan.subplans})
				if filter {
					if key := key_operation(body, table, table, params, mut conn) {
						operation = key
					}
				}
				plan.operations << operation

				if filter {
					add_where_plan(mut &plan, body, params, conn, {
						table.name.id(): &Table{
							...table
						}
					})!
				}
			} else {
				return sqlstate_42p01('table', table_name.str())
			}
		}
		QueryExpression {
			mut table_name := Identifier{
				custom_id: '\$1'
			}

			if from_clause.correlation.name.sub_entity_name != '' {
				table_name = from_clause.correlation.name
			}

			// A derived table can't contain a NEXT VALUE FOR either.
			//
			// ISO/IEC 9075-2:2016(E), 6.14, <next value expression>, Syntax Rules, 1
			next_value_not_allowed := conn.next_value_not_allowed
			if next_value_not_allowed == '' {
				conn.next_value_not_allowed = 'a derived table'
			}
			defer {
				conn.next_value_not_allowed = next_value_not_allowed
			}

			in_derived_table := conn.in_derived_table
			conn.in_derived_table = true
			defer {
				conn.in_derived_table = in_derived_table
			}

			subplan := create_query_expression_plan(from_clause.body, params, mut conn,
				from_clause.correlation)!
			table = add_correlation_plan(mut &plan, table_name, subplan, from_clause.correlation,
				params, mut conn)!

			if filter {
				add_where_plan(mut &plan, body, params, conn, {
					table.name.id(): &Table{
						...table
					}
				})!
			}
		}
	}

	return plan, table
}

// is_same_range_variable returns true if one name is a table and the other is a
// correlation name that's the same as the unqualified name of the table. Two
// tables, or two correlation names, have their full names compared instead.
//
// ISO/IEC 9075-2:2016(E), 7.5, <from clause>, Syntax Rules, 5.c.i.2 and 5.c.ii.1
fn is_same_range_variable(a Identifier, b Identifier) bool {
	return (a.entity_name != '') != (b.entity_name != '')
		&& unqualified_range_variable(a) == unqualified_range_variable(b)
}

// unqualified_range_variable is the name of a table without its catalog and
// schema, or a correlation name.
fn unqualified_range_variable(name Identifier) string {
	return if name.entity_name != '' { name.entity_name } else { name.sub_entity_name }
}

// add_correlation_plan reads the rows of subplan as the table table_name. A
// derived column list in the correlation renames the columns.
fn add_correlation_plan(mut plan Plan, table_name Identifier, subplan Plan, correlation Correlation, params map[string]Value, mut conn Connection) !Table {
	plan.subplans[table_name.id()] = subplan

	// A derived column list must have a name for each column, and each name only
	// once.
	//
	// ISO/IEC 9075-2:2016(E), 7.6, <table reference>, Syntax Rules, 11.b.ii.1
	correlation_columns := correlation.columns
	if correlation_columns.len > 0 && correlation_columns.len != subplan.columns().len {
		return sqlstate_42601('ROW provides the wrong number of columns for the correlation')
	}

	mut seen := map[string]bool{}
	for column in correlation_columns {
		if column.sub_entity_name in seen {
			return sqlstate_42601('column ${column.sub_entity_name} is specified more than once')
		}
		seen[column.sub_entity_name] = true
	}

	mut columns := []Column{}
	for i, col in subplan.columns() {
		columns << Column{
			name:           Identifier{
				entity_name:     table_name.id()
				sub_entity_name: if correlation_columns.len > 0 {
					correlation_columns[i].sub_entity_name
				} else {
					col.name.sub_entity_name
				}
			}
			typ:            col.typ
			not_null:       col.not_null
			from_aggregate: col.from_aggregate
		}
		if conn.collect_columns {
			conn.correlated_columns[columns[i].name.id()] << col.name.id()
		}
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
fn add_where_plan(mut plan Plan, body QuerySpecification, params map[string]Value, conn &Connection, tables map[string]&Table) ! {
	if where := body.table_expression.where_clause {
		mut c := Compiler{
			conn:                   conn
			params:                 params
			tables:                 tables
			next_value_not_allowed: 'WHERE'
		}

		// An aggregate function of an outer query (which is a value here) is allowed.
		//
		// ISO/IEC 9075-2:2016(E), 7.12, <where clause>, Syntax Rules, 1
		// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 7
		if where.compile(mut c)!.contains_agg {
			return sqlstate_42601('an aggregate function cannot be used in WHERE')
		}

		last_operation := plan.operations[plan.operations.len - 1]
		plan.operations << new_where_operation(where, params, conn, last_operation.columns(),
			tables)
	}
}

fn add_group_by_plan(mut plan Plan, group_clause []Identifier, having_clause ?BooleanValueExpression, select_exprs []DerivedColumn, params map[string]Value, mut conn Connection, tables map[string]&Table) ! {
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
	// aggregate function. There are no functional dependencies (T301), so it must
	// be a grouping column.
	//
	// ISO/IEC 9075-2:2016(E), 7.14, <having clause>, Conformance Rules, 1 and 2
	mut grouping_columns := []Column{}
	for col in group_clause {
		grouping_columns << group_column(col, tables)!
	}
	c.grouping_columns = grouping_columns
	for e in select_exprs {
		e.expr.compile(mut c)!
	}

	// The HAVING has the same rule and must be a boolean.
	//
	// ISO/IEC 9075-2:2016(E), 7.14, <having clause>, Syntax Rules, 3
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
					factor: new_boolean_test(BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(new_ref(col)))),
						false, none, false)
				}
			})
			is_asc: true
		}
	}

	// We do not need to sort the set if the all rows belong to the same set.
	if group_clause.len > 0 {
		plan.operations << new_order_operation(order, params, conn, plan.columns(), tables,
			{})
	}

	plan.operations << new_group_operation(select_exprs, group_clause, having_clause,
		params, mut conn, tables)!

	// The HAVING filters the groups, each of which is now a row.
	//
	// ISO/IEC 9075-2:2016(E), 7.14, <having clause>, General Rules, 1
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
				body:        stmt.table_name
				correlation: Correlation{
					name: stmt.correlation_name
				}
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
				body:        stmt.table_name
				correlation: Correlation{
					name: stmt.correlation_name
				}
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
	// only use the columns of the result. A sort key doesn't have to contain a
	// column reference, and it can contain a subquery or an aggregate function
	// (V202-01, V202-02 and V202-03). A column that isn't in the select list would be an extended sort key
	// column, which a grouped query can't have, so it must be a grouping column.
	//
	// ISO/IEC 9075-2:2016(E), 7.17, <query expression>, Syntax Rules, 28
	if stmt.body !is QuerySpecification {
		tables = {
			'': &Table{
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
		result_columns := if stmt.body is QuerySpecification {
			new_expr_operation(mut conn, params, stmt.body.exprs, tables)!.columns()
		} else {
			plan.columns()
		}
		c.set_grouping_columns(stmt.body)!
		mut order := []SortSpecification{}
		c.set_result_columns(stmt.body, result_columns)!
		for spec in stmt.order {
			c.set_distinct_columns(stmt.body, spec.expr)!

			// An aggregate function can only be calculated for the groups of its query.
			//
			// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rules, 7
			if spec.expr.compile(mut c)!.contains_agg
				&& !(stmt.body is QuerySpecification && plan.operations.any(it is GroupOperation)) {
				return sqlstate_42601('an aggregate function cannot be used in ORDER BY unless the query is grouped')
			}

			order << SortSpecification{
				expr:   spec.expr
				is_asc: spec.is_asc
			}
		}

		for mut operation in plan.operations {
			if mut operation is GroupOperation {
				operation.sort_keys = order
				operation.result_columns = c.result_columns.clone()
			}
		}

		if c.next_value_sort_keys.len > 0 {
			plan.operations << &SequenceValuesOperation{
				params:  params
				exprs:   c.next_value_sort_keys
				columns: plan.columns()
				tables:  tables
				conn:    conn
			}
		}

		// The rows may already be in order, when they're read by a key.
		if c.next_value_sort_keys.len > 0 || stmt.body !is QuerySpecification
			|| !use_key_order(mut plan, order, c.result_columns, params, mut conn) {
			plan.operations << new_order_operation(order, params, conn, plan.columns(),
				tables, c.result_columns)
		}
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

// scan_batch_size is how many rows of a table are read at a time when the
// operations after it work on each row by itself, see Plan.execute.
const scan_batch_size = 1024

fn (mut o Plan) execute(_ []Row) ![]Row {
	mut rows := []Row{}
	mut next := 0

	// When the rows of a table are filtered (WHERE) and the select list is
	// calculated, which only look at one row at a time, the rows are read and
	// processed some at a time. Otherwise, every row of the table, and of each
	// of those operations, would be in memory at once. Nothing they do can
	// change the table while it's being read (NEXT VALUE FOR, which does
	// write, is a separate SequenceValuesOperation).
	if o.operations.len > 1 {
		mut first := o.operations[0]
		if mut first is TableOperation {
			mut end := 1
			for end < o.operations.len
				&& (o.operations[end] is WhereOperation || o.operations[end] is ExprOperation) {
				end++
			}
			if end > 1 && !first.table_is_subplan {
				rows = o.execute_scan(mut first, end)!
				next = end
			}
		}
	}

	for i in next .. o.operations.len {
		rows = o.operations[i].execute(rows)!
	}

	return rows
}

// needed_columns is whether each column of table is used by the operations
// before end. The others don't need to be read, because the select list (which
// must be one of them) makes new rows from the columns it uses. It's empty if
// they may all be needed: when there isn't a select list, a subquery is used
// (its columns aren't all known until it runs) or a column isn't one of the
// table's. The expressions have already been compiled when the plan was made,
// so they compile again without an error.
fn (mut o Plan) needed_columns(mut table TableOperation, end int) ![]bool {
	if !o.operations[1..end].any(it is ExprOperation) {
		return []
	}

	mut conn := table.conn
	warnings := conn.warnings.clone()
	conn.collect_columns = true
	conn.collected_columns = map[string]bool{}
	conn.collected_subquery = false
	defer {
		conn.collect_columns = false
		conn.collected_columns = map[string]bool{}
		conn.collected_subquery = false
		conn.warnings = warnings
	}

	for i in 1 .. end {
		operation := o.operations[i]
		if operation is WhereOperation {
			mut c := Compiler{
				conn:   conn
				params: operation.params
				tables: operation.tables
			}
			operation.condition.compile(mut c)!
		} else if operation is ExprOperation {
			for expr in operation.exprs {
				mut c := Compiler{
					conn:   conn
					params: operation.params
					tables: operation.tables
				}
				expr.expr.compile(mut c)!
			}
		}
	}

	ids := table.table.columns.map(it.name.id())
	if conn.collected_subquery || conn.collected_columns.keys().any(it !in ids) {
		return []
	}

	return ids.map(it in conn.collected_columns)
}

// execute_scan reads the rows of table some at a time, passing each batch
// through the operations before end.
fn (mut o Plan) execute_scan(mut table TableOperation, end int) ![]Row {
	mut catalog := table.conn.catalog_for(table.table_name)
	needed := o.needed_columns(mut table, end)!
	mut scanner := catalog.storage.scan_rows(table.table_name, needed)!
	defer {
		scanner.finish()
	}

	mut rows := []Row{}
	for {
		mut batch := scanner.next_rows(scan_batch_size)!
		if batch.len == 0 {
			break
		}
		for i in 1 .. end {
			batch = o.operations[i].execute(batch)!
		}
		rows << batch
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
		Column{
			name: Identifier{
				sub_entity_name: 'EXPLAIN'
			}
			typ:  new_type('VARCHAR', 0, 0)
		},
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
	tables  map[string]&Table
}

fn new_expr_operation(mut conn Connection, params map[string]Value, select_list SelectList, tables map[string]&Table) !ExprOperation {
	mut exprs := []DerivedColumn{}
	mut columns := []Column{}

	match select_list {
		AsteriskExpr {
			for _, table in tables {
				columns << table.columns
				for column in table.columns {
					exprs << DerivedColumn{ValueExpression(CommonValueExpression(DatetimePrimary(ValueExpressionPrimary(NonparenthesizedValueExpressionPrimary(new_ref(column.name)))))), Identifier{
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
						// Only a column reference or an AS clause names the column,
						// otherwise its name is implementation-dependent.
						//
						// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 19
						// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Conformance Rules, 6
						mut column_name := 'COL${columns.len + 1}'
						mut unnamed := true
						if item.as_clause.sub_entity_name != '' {
							column_name = item.as_clause.sub_entity_name
							unnamed = false
						} else if column := item.column_reference() {
							column_name = column.sub_entity_name
							unnamed = false
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

						compiled := expr.compile(mut c)!
						columns << Column{
							name:           col
							typ:            compiled.typ
							not_null:       if column := item.column_reference() {
								column_not_null(column, conn, tables)
							} else {
								false
							}
							unnamed:        unnamed
							from_aggregate: compiled.contains_agg
						}

						exprs << DerivedColumn{expr, col}
					}
				}
			}
		}
	}

	// "t.*" has no columns if t only has common columns of a <joined table>, but a
	// table has to have at least one column.
	//
	// ISO/IEC 9075-2:2016(E), 4.15, Tables
	// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 8.g.i
	if columns.len == 0 {
		return sqlstate_42601('the select list has no columns')
	}

	// A result can have more than one column with the same name, such as a.id
	// and b.id. Each one after the first is kept in the row under a different
	// key, see Row.get_column.
	//
	// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 19
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
			columns[i] = Column{
				name:     Identifier{
					...columns[i].name
					custom_id: key
				}
				typ:      columns[i].typ
				not_null: columns[i].not_null
				unnamed:  columns[i].unnamed
			}
		}
	}

	return ExprOperation{conn, params, exprs, columns, tables}
}

// column_not_null is true if a column reference in the select list is to a
// column of tables that can't be NULL. Any other expression can be NULL because
// T101 isn't supported, as can a column of an outer query.
//
// ISO/IEC 9075-2:2016(E), 7.16, <query specification>, Syntax Rules, 20 and 21
fn column_not_null(reference Identifier, conn &Connection, tables map[string]&Table) bool {
	for _, table in tables {
		if column := table.column(reference.sub_entity_name) {
			if reference.is_column_of_table(conn, table) {
				return column.not_null
			}
		}
	}

	return false
}

// qualified_asterisk_table returns the table that "t.*" refers to.
fn qualified_asterisk_table(e QualifiedAsteriskExpr, mut conn Connection, tables map[string]&Table) !Table {
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
			factor: new_boolean_test(BooleanPrimary(BooleanPredicand(NonparenthesizedValueExpressionPrimary(new_ref(column.name)))),
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
	mut new_rows := []Row{cap: rows.len}
	// Each expression is compiled on the first row, then kept for the rows
	// after it.
	mut compiled := []CompileResult{cap: o.exprs.len}

	// Every row has the same keys. An expression with the same id as one before
	// it replaces its value (slots is the position of each expression).
	mut keys := []string{cap: o.exprs.len}
	mut slots := []int{cap: o.exprs.len}
	for expr in o.exprs {
		id := expr.as_clause.id()
		mut slot := keys.index(id)
		if slot < 0 {
			slot = keys.len
			keys << id
		}
		slots << slot
	}

	for row in rows {
		o.conn.begin_row()
		if compiled.len == 0 {
			for expr in o.exprs {
				compiled << expr.expr.compile(mut c)!
			}
		}
		mut values := []Value{len: keys.len}
		for i, result in compiled {
			values[slots[i]] = result.run(mut o.conn, row, o.params)!
		}

		// The id of the row is kept so that the current row of a cursor can
		// be changed by a positioned DELETE or UPDATE.
		new_rows << Row{row.id, row.tid, RowData{keys, values}}
	}

	return new_rows
}
