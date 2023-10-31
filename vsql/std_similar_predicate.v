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
//~ <similar pattern> /* CharacterValueExpression */ ::=
//~     <character value expression>

// SimilarPredicate for "SIMILAR TO" and "NOT SIMILAR TO".
struct SimilarPredicate {
	left  ?RowValueConstructorPredicand
	right CharacterValueExpression
	not   bool
}

fn (e SimilarPredicate) pstr(params map[string]Value) string {
	if left := e.left {
		if e.not {
			return '${left.pstr(params)} NOT SIMILAR TO ${e.right.pstr(params)}'
		}

		return '${left.pstr(params)} SIMILAR TO ${e.right.pstr(params)}'
	}

	return e.right.pstr(params)
}

fn (e SimilarPredicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	if l := e.left {
		left := l.eval(mut conn, data, params)!
		right := e.right.eval(mut conn, data, params)!

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

	return e.right.eval(mut conn, data, params)
}

fn (e SimilarPredicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if left := e.left {
		return left.is_agg(conn, row, params)!
	}

	return false
}

fn (e SimilarPredicate) resolve_identifiers(conn &Connection, tables map[string]Table) !SimilarPredicate {
	left := if t := e.left {
		?RowValueConstructorPredicand(t.resolve_identifiers(conn, tables)!)
	} else {
		?RowValueConstructorPredicand(none)
	}

	return SimilarPredicate{left, e.right.resolve_identifiers(conn, tables)!, e.not}
}

fn parse_similar_pred(left RowValueConstructorPredicand, like SimilarPredicate) !SimilarPredicate {
	return SimilarPredicate{left, like.right, like.not}
}

fn parse_similar(expr CharacterValueExpression) !SimilarPredicate {
	return SimilarPredicate{none, expr, false}
}

fn parse_not_similar(expr CharacterValueExpression) !SimilarPredicate {
	return SimilarPredicate{none, expr, true}
}
