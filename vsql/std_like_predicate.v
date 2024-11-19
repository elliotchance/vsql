module vsql

import regex

// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>
//
// # Function
//
// Specify a pattern-match comparison.
//
// # Format
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

fn (e CharacterLikePredicate) compile(mut c Compiler) !CompileResult {
	compiled_right := e.right.compile(mut c)!

	if l := e.left {
		compiled_l := l.compile(mut c)!

		return CompileResult{
			run:          fn [e, compiled_l, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
				left := compiled_l.run(mut conn, data, params)!
				right := compiled_right.run(mut conn, data, params)!

				// Make sure we escape any regexp characters.
				escaped_regex := right.string_value().replace('+', '\\+').replace('?',
					'\\?').replace('*', '\\*').replace('|', '\\|').replace('.', '\\.').replace('(',
					'\\(').replace(')', '\\)').replace('[', '\\[').replace('{', '\\{').replace('_',
					'.').replace('%', '.*')

				mut re := regex.regex_opt('^${escaped_regex}$') or {
					return error('cannot compile regexp: ^${escaped_regex}$: ${err}')
				}
				result := re.matches_string(left.string_value())

				if e.not {
					return new_boolean_value(!result)
				}

				return new_boolean_value(result)
			}
			typ:          new_type('BOOLEAN', 0, 0)
			contains_agg: compiled_right.contains_agg || compiled_l.contains_agg
		}
	}

	return compiled_right
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
