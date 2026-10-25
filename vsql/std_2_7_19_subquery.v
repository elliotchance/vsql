module vsql

// ISO/IEC 9075-2:2016(E), 7.19, <subquery>
//
// Specify a scalar value, a row, or a table derived from a <query expression>.

type TablePrimaryBody = Identifier | QueryExpression

// A Subquery is a <query expression> used in an expression, such as in EXISTS
// or IN. query is a reference
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

// plan creates the plan for the subquery. It's evaluated with run.
fn (e Subquery) plan(mut c Compiler) !Plan {
	// ISO/IEC 9075-2:2016(E), 11.9, <check constraint definition>, Conformance
	// Rule 1 (Feature F671)
	if c.check_constraint {
		return sqlstate_42601('a subquery cannot be used in a CHECK constraint')
	}

	c.conn.subquery_depth++
	defer {
		c.conn.subquery_depth--
	}

	return create_query_expression_plan(*e.query, c.params, mut c.conn, Correlation{})!
}

// run_subquery returns the rows of a subquery from its plan.
fn run_subquery(mut conn Connection, plan Plan) ![]Row {
	conn.subquery_depth++
	defer {
		conn.subquery_depth--
	}

	mut p := plan

	return p.execute([]Row{})!
}
