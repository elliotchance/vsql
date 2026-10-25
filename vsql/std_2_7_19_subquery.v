module vsql

// ISO/IEC 9075-2:2016(E), 7.19, <subquery>
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
// ISO/IEC 9075-2:2016(E), 6.6, <identifier chain>, Syntax Rule 8
struct SubqueryScope {
	tables  map[string]Table
	context Identifier
	// grouping_columns is set when the subquery is in the select list (or
	// HAVING) of a grouped query, so an outer reference must be one of these
	// columns.
	grouping_columns ?[]Column
mut:
	row Row
}

// SubqueryPlan is the plan of a subquery, and the scope it's evaluated in.
struct SubqueryPlan {
	plan  Plan
	scope SubqueryScope
}

// plan creates the plan for the subquery. It's evaluated with run_subquery.
fn (e Subquery) plan(mut c Compiler) !SubqueryPlan {
	// ISO/IEC 9075-2:2016(E), 11.9, <check constraint definition>, Conformance
	// Rule 1 (Feature F671)
	if c.restricted != '' {
		return sqlstate_42601('a subquery cannot be used in ${c.restricted}')
	}

	// ISO/IEC 9075-2:2016(E), 6.9, <set function specification>, Syntax Rule 1
	if c.in_aggregate {
		return sqlstate_42601('a subquery cannot be used in an aggregate function')
	}

	scope := SubqueryScope{
		tables:           c.tables
		context:          c.context
		grouping_columns: c.grouping_columns
	}
	c.conn.subquery_scopes << scope
	defer {
		c.conn.subquery_scopes.pop()
	}

	return SubqueryPlan{create_query_expression_plan(*e.query, c.params, mut c.conn,
		Correlation{})!, scope}
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

// run_subquery returns the rows of a subquery, where data is the row of the
// query that contains it.
fn run_subquery(mut conn Connection, plan SubqueryPlan, data Row) ![]Row {
	conn.subquery_scopes << SubqueryScope{
		...plan.scope
		row: data
	}
	defer {
		conn.subquery_scopes.pop()
	}

	mut p := plan.plan

	return p.execute([]Row{})!
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

// compile is a <scalar subquery>. It's NULL when there are no rows.
//
// ISO/IEC 9075-2:2016(E), 7.19, <subquery>, Syntax Rules 2 and 5, General Rule 3
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
		contains_agg: false
	}
}
