// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>

module vsql

import regex

// Format
//~
//~ <like predicate> /* CharacterLikePredicate */ ::=
//~     <character like predicate>
//~
//~ <character like predicate> /* CharacterLikePredicate */ ::=
//~     <row value predicand> <character like predicate part 2>   -> like_pred
//~
//~ <character like predicate part 2> /* CharacterLikePredicate */ ::=
//~     LIKE <character pattern>       -> like
//~   | NOT LIKE <character pattern>   -> not_like
//~
//~ <character pattern> /* CharacterValueExpression */ ::=
//~     <character value expression>

// CharacterLikePredicate for "LIKE" and "NOT LIKE".
struct CharacterLikePredicate {
	left  ?RowValueConstructorPredicand
	right CharacterValueExpression
	not   bool
}

fn (e CharacterLikePredicate) pstr(params map[string]Value) string {
	if left := e.left {
		if e.not {
			return '${left.pstr(params)} NOT LIKE ${e.right.pstr(params)}'
		}

		return '${left.pstr(params)} LIKE ${e.right.pstr(params)}'
	}

	return e.right.pstr(params)
}

fn (e CharacterLikePredicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	if l := e.left {
		left := l.eval(mut conn, data, params)!
		right := e.right.eval(mut conn, data, params)!

		// Make sure we escape any regexp characters.
		escaped_regex := right.string_value().replace('+', '\\+').replace('?', '\\?').replace('*',
			'\\*').replace('|', '\\|').replace('.', '\\.').replace('(', '\\(').replace(')',
			'\\)').replace('[', '\\[').replace('{', '\\{').replace('_', '.').replace('%',
			'.*')

		mut re := regex.regex_opt('^${escaped_regex}$') or {
			return error('cannot compile regexp: ^${escaped_regex}$: ${err}')
		}
		result := re.matches_string(left.string_value())

		if e.not {
			return new_boolean_value(!result)
		}

		return new_boolean_value(result)
	}

	return e.right.eval(mut conn, data, params)!
}

fn (e CharacterLikePredicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if left := e.left {
		return left.is_agg(conn, row, params)!
	}

	return false
}

fn (e CharacterLikePredicate) resolve_identifiers(conn &Connection, tables map[string]Table) !CharacterLikePredicate {
	left := if t := e.left {
		?RowValueConstructorPredicand(t.resolve_identifiers(conn, tables)!)
	} else {
		?RowValueConstructorPredicand(none)
	}

	return CharacterLikePredicate{left, e.right.resolve_identifiers(conn, tables)!, e.not}
}

fn parse_like_pred(left RowValueConstructorPredicand, like CharacterLikePredicate) !CharacterLikePredicate {
	return CharacterLikePredicate{left, like.right, like.not}
}

fn parse_like(expr CharacterValueExpression) !CharacterLikePredicate {
	return CharacterLikePredicate{none, expr, false}
}

fn parse_not_like(expr CharacterValueExpression) !CharacterLikePredicate {
	return CharacterLikePredicate{none, expr, true}
}
