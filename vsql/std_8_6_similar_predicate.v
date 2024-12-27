module vsql

import regex

// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>
//
// Specify a character string similarity by means of a regular expression.

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

fn (e SimilarPredicate) compile(mut c Compiler) !CompileResult {
	if l := e.left {
		compiled_l := l.compile(mut c)!
		compiled_right := e.right.compile(mut c)!

		return CompileResult{
			run:          fn [e, compiled_l, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
				left := compiled_l.run(mut conn, data, params)!
				right := compiled_right.run(mut conn, data, params)!

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
			typ:          new_type('BOOLEAN', 0, 0)
			contains_agg: compiled_l.contains_agg || compiled_right.contains_agg
		}
	}

	return e.right.compile(mut c)!
}
