// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>

module vsql

import regex

// Format
//~
//~ <similar predicate> /* SimilarPredicate */ ::=
//~     <row value predicand> <similar predicate part 2>   -> similar_pred
//~
//~ <similar predicate part 2> /* SimilarPredicate */ ::=
//~     SIMILAR TO <similar pattern>       -> similar
//~   | NOT SIMILAR TO <similar pattern>   -> not_similar
//~
//~ <similar pattern> /* Expr */ ::=
//~     <character value expression>

// SimilarPredicate for "SIMILAR TO" and "NOT SIMILAR TO".
struct SimilarPredicate {
	left  Expr
	right Expr
	not   bool
}

fn (e SimilarPredicate) pstr(params map[string]Value) string {
	if e.not {
		return '${e.left.pstr(params)} NOT SIMILAR TO ${e.right.pstr(params)}'
	}

	return '${e.left.pstr(params)} SIMILAR TO ${e.right.pstr(params)}'
}

fn (e SimilarPredicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	left := eval_as_value(mut conn, data, e.left, params)!
	right := eval_as_value(mut conn, data, e.right, params)!

	regexp := '^${right.string_value().replace('.', '\\.').replace('_', '.').replace('%',
		'.*')}$'
	mut re := regex.regex_opt(regexp) or {
		return error('cannot compile regexp: ${regexp}: ${err}')
	}
	result := re.matches_string(left.string_value())

	if e.not {
		return new_boolean_value(!result)
	}

	return new_boolean_value(result)
}

fn (e SimilarPredicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if expr_is_agg(conn, e.left, row, params)! {
		return nested_agg_unsupported(Predicate(e))
	}

	return false
}

fn (e SimilarPredicate) resolve_identifiers(conn &Connection, tables map[string]Table) !Expr {
	return Predicate(SimilarPredicate{resolve_identifiers(conn, e.left, tables)!, resolve_identifiers(conn,
		e.right, tables)!, e.not})
}

fn parse_similar_pred(left Expr, like SimilarPredicate) !SimilarPredicate {
	return SimilarPredicate{left, like.right, like.not}
}

fn parse_similar(expr Expr) !SimilarPredicate {
	return SimilarPredicate{NoExpr{}, expr, false}
}

fn parse_not_similar(expr Expr) !SimilarPredicate {
	return SimilarPredicate{NoExpr{}, expr, true}
}
