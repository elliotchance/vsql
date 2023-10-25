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
//~ <character pattern> /* Expr */ ::=
//~     <character value expression>

// CharacterLikePredicate for "LIKE" and "NOT LIKE".
struct CharacterLikePredicate {
	left  Expr
	right Expr
	not   bool
}

fn (e CharacterLikePredicate) pstr(params map[string]Value) string {
	if e.not {
		return '${e.left.pstr(params)} NOT LIKE ${e.right.pstr(params)}'
	}

	return '${e.left.pstr(params)} LIKE ${e.right.pstr(params)}'
}

fn (e CharacterLikePredicate) eval(mut conn Connection, data Row, params map[string]Value) !Value {
	left := eval_as_value(mut conn, data, e.left, params)!
	right := eval_as_value(mut conn, data, e.right, params)!

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

fn (e CharacterLikePredicate) is_agg(conn &Connection, row Row, params map[string]Value) !bool {
	if expr_is_agg(conn, e.left, row, params)! {
		return nested_agg_unsupported(Predicate(e))
	}

	return false
}

fn (e CharacterLikePredicate) resolve_identifiers(conn &Connection, tables map[string]Table) !Expr {
	return Predicate(CharacterLikePredicate{resolve_identifiers(conn, e.left, tables)!, resolve_identifiers(conn,
		e.right, tables)!, e.not})
}

fn parse_like_pred(left Expr, like CharacterLikePredicate) !CharacterLikePredicate {
	return CharacterLikePredicate{left, like.right, like.not}
}

fn parse_like(expr Expr) !CharacterLikePredicate {
	return CharacterLikePredicate{NoExpr{}, expr, false}
}

fn parse_not_like(expr Expr) !CharacterLikePredicate {
	return CharacterLikePredicate{NoExpr{}, expr, true}
}
