module vsql

// ISO/IEC 9075-2:2023, 8.13, <match predicate>
//
// Specify a test for matching rows.

// MatchPredicate is "x MATCH [UNIQUE] [SIMPLE | PARTIAL | FULL] (SELECT ...)".
// The match_type is always given (SIMPLE when it's left out). It's never
// UNKNOWN.
struct MatchPredicate {
	expr       RowValueConstructorPredicand
	unique     bool
	match_type string // SIMPLE, PARTIAL or FULL
	subquery   Subquery
}

fn new_match_predicate(unique bool, match_type string, subquery TablePrimary) MatchPredicate {
	return MatchPredicate{
		unique:     unique
		match_type: match_type
		subquery:   new_subquery(subquery.body as QueryExpression)
	}
}

fn (e MatchPredicate) pstr(params map[string]Value) string {
	unique := if e.unique { ' UNIQUE' } else { '' }

	return '${e.expr.pstr(params)} MATCH${unique} ${e.match_type} ${e.subquery.pstr(params)}'
}

// The row and the rows of the subquery must be comparable, and are compared
// like the operands of an equality operation (see plan_compared_subquery).
//
// ISO/IEC 9075-2:2023, 8.13, <match predicate>, Syntax Rules, 1 and 2
fn (e MatchPredicate) compile(mut c Compiler) !CompileResult {
	mut compiled_expr := e.expr.compile_fields(mut c)!
	plan := plan_compared_subquery(mut c, e.subquery, mut compiled_expr)!

	return CompileResult{
		run:          fn [e, compiled_expr, plan] (mut conn Connection, data Row, params map[string]Value) !Value {
			expr := run_fields(mut conn, compiled_expr, data, params)!
			rows := subquery_rows(mut conn, plan, data)!

			return new_boolean_value(is_match(conn, expr, e.unique, e.match_type, rows)!)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_expr.any(it.contains_agg) || plan.contains_agg
	}
}

// is_match is the result of the match predicate for the row expr (a value that
// isn't a row is a row with one field). A row with a NULL always matches with
// SIMPLE, and a row that's all NULL always matches. Otherwise, it matches if
// one of the rows (or exactly one, when unique) has the same values. The NULLs
// aren't compared with PARTIAL, and FULL never matches a row with some (but not
// all) NULLs.
//
// ISO/IEC 9075-2:2023, 8.13, <match predicate>, General Rules, 1, 2, 3 and 4
fn is_match(conn &Connection, expr []Value, unique bool, match_type string, rows [][]Value) !bool {
	nulls := expr.filter(it.is_null).len
	if nulls == expr.len || (nulls > 0 && match_type == 'SIMPLE') {
		return true
	}
	if nulls > 0 && match_type == 'FULL' {
		return false
	}

	mut matches := 0
	for row in rows {
		if is_partial_match(conn, expr, row)! {
			matches++
		}
	}

	return if unique { matches == 1 } else { matches > 0 }
}

// is_partial_match is true if each value of expr that isn't NULL is equal to
// the corresponding value of row.
fn is_partial_match(conn &Connection, expr []Value, row []Value) !bool {
	for i, value in expr {
		if !value.is_null && compare(conn, value, row[i])! != .is_equal {
			return false
		}
	}

	return true
}
