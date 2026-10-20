module vsql

// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>
//
// Specify a pattern-match comparison.

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

	return e.right.pstr(params) // coverage:ignore (the grammar always gives LIKE a left side)
}

fn (e CharacterLikePredicate) compile(mut c Compiler) !CompileResult {
	compiled_right := e.right.compile(mut c)!

	if l := e.left {
		compiled_l := l.compile(mut c)!

		return CompileResult{
			run:          fn [e, compiled_l, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
				left := compiled_l.run(mut conn, data, params)!
				right := compiled_right.run(mut conn, data, params)!

				// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules, 3a.i
				if left.is_null || right.is_null {
					return new_unknown_value()
				}

				result := like_matches(left.string_value(), right.string_value())

				if e.not {
					return new_boolean_value(!result)
				}

				return new_boolean_value(result)
			}
			typ:          new_type('BOOLEAN', 0, 0)
			contains_agg: compiled_right.contains_agg || compiled_l.contains_agg
		}
	}

	return compiled_right // coverage:ignore (the grammar always gives LIKE a left side)
}

// like_matches reports whether s matches pattern, where "%" matches any number
// of characters (including none) and "_" matches exactly one character
// (8.5 General Rule 3d). All other characters must match exactly.
fn like_matches(s string, pattern string) bool {
	chars := s.runes()
	pat := pattern.runes()
	mut i := 0 // position in chars
	mut j := 0 // position in pat

	// When a "%" is found, its position in the pattern and the position in
	// chars it started matching from are remembered. If the rest of the pattern
	// fails to match, the "%" takes one more character and the match is tried
	// again from there.
	mut percent := -1
	mut percent_i := 0

	for i < chars.len {
		if j < pat.len && pat[j] == `%` {
			percent = j
			percent_i = i
			j++
		} else if j < pat.len && (pat[j] == `_` || pat[j] == chars[i]) {
			i++
			j++
		} else if percent >= 0 {
			percent_i++
			i = percent_i
			j = percent + 1
		} else {
			return false
		}
	}

	// Only "%" can match the empty rest of the string.
	for j < pat.len && pat[j] == `%` {
		j++
	}

	return j == pat.len
}
