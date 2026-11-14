module vsql

// ISO/IEC 9075-2:2023, 7.19, <subquery>
//
// Specify a scalar value, a row, or a table derived from a <query expression>.

type TablePrimaryBody = Identifier | QueryExpression

// A Subquery is a <query expression> used in an expression, such as in EXISTS
// or IN. In a value expression it's a <scalar subquery>. query is a reference
// because a QueryExpression can contain a Subquery, and V stores a sum type's
// value inline.
struct Subquery {
	query &QueryExpression
}

fn new_subquery(query QueryExpression) Subquery {
	return Subquery{&query}
}

fn (e Subquery) pstr(params map[string]Value) string {
	return '(${e.query.pstr(params)})'
}

// A SubqueryScope is the query that contains a subquery, so that the subquery
// can refer to its columns (a correlated subquery, such as
// "SELECT * FROM t1 WHERE EXISTS (SELECT * FROM t2 WHERE t2.x = t1.x)").
//
// The scope is pushed onto Connection.subquery_scopes while the subquery is
// planned, so that a column that isn't in the subquery can be found in a query
// that contains it (the innermost first), see Identifier.compile_outer. It's
// pushed again with the row of the containing query each time the subquery is
// evaluated.
//
// ISO/IEC 9075-2:2023, 6.6, <identifier chain>, Syntax Rules, 8
struct SubqueryScope {
	tables  map[string]&Table
	context Identifier
	// grouping_columns is set when the subquery is in the select list (or
	// HAVING) of a grouped query, so an outer reference must be one of these
	// columns.
	grouping_columns ?[]Column
	// aggregation_query is set when the subquery is in a VALUES, which isn't a
	// query specification, see values_aggregation_query.
	aggregation_query ?int
mut:
	row Row
	// aggregates collects the aggregate functions in the subquery that are of
	// the containing query, see Compiler.aggregation_scope.
	aggregates []AggregateFunction
	// varies is set while the subquery is planned or evaluated if its result can
	// be different each time it's evaluated in a statement, because it refers to
	// a query that contains it (see vary_subqueries) or it has a non-deterministic
	// function. Otherwise, it's only evaluated once for each statement (see
	// run_subquery).
	varies bool
}

// SubqueryResult is the rows of a subquery that has been evaluated in the
// statement, or varies is set if it must be evaluated each time.
struct SubqueryResult {
	rows   []Row
	varies bool
}

// vary_subqueries marks the subqueries from scope i (and the subqueries in them)
// as having a result that can be different each time they're evaluated, such as
// when they have a reference to the row of the query that contains subquery i.
fn (mut conn Connection) vary_subqueries(i int) {
	for j := i; j < conn.subquery_scopes.len; j++ {
		conn.subquery_scopes[j].varies = true
	}
}

// SubqueryPlan is the plan of a subquery, and the scope it's evaluated in.
// contains_agg is true if the subquery has an aggregate function of the
// containing query, which makes that query grouped.
struct SubqueryPlan {
	plan         Plan
	scope        SubqueryScope
	contains_agg bool
	// query identifies the subquery's results in Connection.subquery_results, or
	// it's nil when the subquery must be evaluated each time (see
	// SubqueryScope.varies).
	query voidptr
}

// plan creates the plan for the subquery. It's evaluated with run_subquery.
fn (e Subquery) plan(mut c Compiler) !SubqueryPlan {
	// ISO/IEC 9075-2:2023, 11.9, <check constraint definition>, Conformance
	// Rules, 1 (Feature F671)
	// ISO/IEC 9075-2:2023, 11.4, <column definition>, Syntax Rules, 10.f
	if c.restricted != '' {
		return sqlstate_42601('a subquery cannot be used in ${c.restricted}')
	}

	// This is also the <filter clause> of an aggregate function (see
	// compile_filter).
	//
	// ISO/IEC 9075-2:2023, 6.9, <set function specification>, Syntax Rules, 1
	// ISO/IEC 9075-2:2023, 10.9, <aggregate function>, Syntax Rules, 8
	if c.in_aggregate {
		return sqlstate_42601('a subquery cannot be used in an aggregate function')
	}

	if c.conn.collect_columns {
		c.conn.collected_subquery = true
	}

	scope := SubqueryScope{
		tables:            c.tables
		context:           c.context
		grouping_columns:  c.grouping_columns
		aggregation_query: c.aggregation_query
	}
	in_derived_table := c.conn.in_derived_table
	c.conn.in_derived_table = false
	defer {
		c.conn.in_derived_table = in_derived_table
	}
	// An aggregate function of a query that contains this subquery is a value of
	// that query's row (or group), see Compiler.aggregation_scope.
	outer_aggregates := c.conn.subquery_scopes.map(it.aggregates.len)
	c.conn.subquery_scopes << scope
	plan := create_query_expression_plan(*e.query, c.params, mut c.conn, Correlation{}) or {
		c.conn.subquery_scopes.pop()
		return err
	}

	// The aggregate functions of this query are calculated with its other
	// aggregate functions (see GroupOperation).
	planned := c.conn.subquery_scopes.pop()
	aggregates := planned.aggregates
	c.aggregates << aggregates

	mut varies := planned.varies || aggregates.len > 0
	for i, count in outer_aggregates {
		if c.conn.subquery_scopes[i].aggregates.len > count {
			varies = true
		}
	}

	query := if varies { unsafe { nil } } else { voidptr(e.query) }

	return SubqueryPlan{plan, scope, aggregates.len > 0, query}
}

// plan_column is plan for a subquery that must have one column, such as for
// "x IN (SELECT ...)".
fn (e Subquery) plan_column(mut c Compiler) !SubqueryPlan {
	plan := e.plan(mut c)!
	if plan.plan.columns().len != 1 {
		return sqlstate_42601('subquery must return only one column')
	}

	return plan
}

// plan_row is plan for a subquery whose rows are compared with a row of the
// given degree, such as for "(x, y) IN (SELECT ...)".
fn (e Subquery) plan_row(mut c Compiler, degree int) !SubqueryPlan {
	if degree == 1 {
		return e.plan_column(mut c)!
	}

	plan := e.plan(mut c)!
	if plan.plan.columns().len != degree {
		return sqlstate_42601('subquery must return ${degree} columns')
	}

	return plan
}

// run_subquery returns the rows of a subquery, where data is the row of the
// query that contains it.
//
// A subquery that doesn't refer to the queries that contain it (and doesn't
// have a non-deterministic function) has the same result every time, so it's
// only executed the first time it's evaluated in each statement.
fn run_subquery(mut conn Connection, plan SubqueryPlan, data Row) ![]Row {
	cache := plan.query != unsafe { nil }
	if cache {
		if result := conn.subquery_results[plan.query] {
			if !result.varies {
				return result.rows
			}
		}
	}

	conn.subquery_scopes << SubqueryScope{
		...plan.scope
		row: data
	}
	defer {
		conn.subquery_scopes.pop()
	}

	mut p := plan.plan
	rows := p.execute([]Row{})!

	// The expressions of a subquery are compiled when it's planned, so that's
	// when it's found to vary. In case an expression is only compiled when it's
	// evaluated, the scope is checked again, and once it has varied it's evaluated
	// each time for the rest of the statement, even if the expression isn't
	// compiled again. If nothing marked it, the result didn't depend on anything
	// that can change, so it's the same every time.
	if cache {
		previous := conn.subquery_results[plan.query] or { SubqueryResult{} }
		conn.subquery_results[plan.query] = SubqueryResult{rows, previous.varies
			|| conn.subquery_scopes.last().varies}
	}

	return rows
}

// subquery_values runs the plan of a subquery and returns the values of the
// first (and only) column of every row.
fn subquery_values(mut conn Connection, plan SubqueryPlan, data Row) ![]Value {
	column := plan.plan.columns()[0]
	mut values := []Value{}
	for row in run_subquery(mut conn, plan, data)! {
		values << row.get_column(column)!
	}

	return values
}

// subquery_rows runs the plan of a subquery and returns the values of every
// row.
fn subquery_rows(mut conn Connection, plan SubqueryPlan, data Row) ![][]Value {
	columns := plan.plan.columns()
	mut rows := [][]Value{}
	for row in run_subquery(mut conn, plan, data)! {
		mut values := []Value{cap: columns.len}
		for column in columns {
			values << row.get_column(column)!
		}
		rows << values
	}

	return rows
}

// compile is a <scalar subquery>. It's NULL when there are no rows.
//
// ISO/IEC 9075-2:2023, 7.19, <subquery>, Syntax Rules, 2 and 5
// ISO/IEC 9075-2:2023, 7.19, <subquery>, General Rules, 3
fn (e Subquery) compile(mut c Compiler) !CompileResult {
	plan := e.plan_column(mut c)!
	typ := plan.plan.columns()[0].typ

	return CompileResult{
		run:          fn [plan, typ] (mut conn Connection, data Row, params map[string]Value) !Value {
			values := subquery_values(mut conn, plan, data)!
			if values.len > 1 {
				return sqlstate_21000()
			}

			if values.len == 0 {
				return Value{
					typ:     typ
					is_null: true
				}
			}

			return values[0]
		}
		typ:          typ
		contains_agg: plan.contains_agg
	}
}
