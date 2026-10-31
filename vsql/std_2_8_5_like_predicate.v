module vsql

// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>
//
// Specify a pattern-match comparison.

// CharacterLikePredicate for "LIKE" and "NOT LIKE", with an optional
// "ESCAPE".
struct CharacterLikePredicate {
	left   RowValueConstructorPredicand
	right  CharacterValueExpression
	escape ?&CharacterValueExpression
	not    bool
}

// CharacterLikePredicatePart2 is the "LIKE <pattern>" (or "NOT LIKE") while
// it's being parsed, before it has the value on the left.
struct CharacterLikePredicatePart2 {
	right  CharacterValueExpression
	escape ?&CharacterValueExpression
	not    bool
}

fn ref_character_value_expression(e CharacterValueExpression) &CharacterValueExpression {
	return &e
}

fn (e CharacterLikePredicate) pstr(params map[string]Value) string {
	mut s := e.left.pstr(params)
	if e.not {
		s += ' NOT'
	}
	s += ' LIKE ${e.right.pstr(params)}'

	if escape := e.escape {
		s += ' ESCAPE ${escape.pstr(params)}'
	}

	return s
}

// The operands aren't checked to be character strings (#780).
//
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, Syntax Rules, 1
fn (e CharacterLikePredicate) compile(mut c Compiler) !CompileResult {
	compiled_right := e.right.compile(mut c)!
	compiled_l := e.left.compile(mut c)!
	compiled_escape := if escape := e.escape {
		escape.compile(mut c)!
	} else {
		CompileResult{
			run:          unsafe { nil }
			typ:          Type{}
			contains_agg: false
		}
	}
	has_escape := e.escape != none

	return CompileResult{
		run:          fn [e, compiled_l, compiled_right, compiled_escape, has_escape] (mut conn Connection, data Row, params map[string]Value) !Value {
			left := compiled_l.run(mut conn, data, params)!
			right := compiled_right.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules, 3.a
			if left.is_null || right.is_null {
				return new_unknown_value()
			}

			mut escape := ?rune(none)
			if has_escape {
				escape_value := compiled_escape.run(mut conn, data, params)!

				// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules,
				// 3.a.ii
				if escape_value.is_null {
					return new_unknown_value()
				}

				escape = escape_character(escape_value)!
			}

			result := like_matches(left.string_value(), like_pattern(right.string_value(),
				escape)!)

			// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, Syntax Rules, 3.b
			// and 3.c
			if e.not {
				return new_boolean_value(!result)
			}

			return new_boolean_value(result)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_right.contains_agg || compiled_l.contains_agg
			|| compiled_escape.contains_agg
	}
}

// escape_character is the character of the ESCAPE of a LIKE or SIMILAR TO, or a
// SQLSTATE 22019 error if it isn't exactly one character.
//
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules, 3.b.i.1
// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>, General Rules, 3.a
fn escape_character(value Value) !rune {
	runes := value.string_value().runes()
	if runes.len != 1 {
		return sqlstate_22019()
	}

	return runes[0]
}

// LikeChar is one character of a LIKE pattern. "%" and "_" are wildcards
// unless they were escaped.
struct LikeChar {
	ch       rune
	wildcard bool
}

// like_pattern splits pattern into its characters. With an escape character,
// the escape character followed by "%", "_" or itself is that character
// matched literally, and any other use of it is a SQLSTATE 22025 error. Without
// an escape character, every "%" and "_" is a wildcard.
//
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules, 3.b.i.2
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules, 3.b.ii
fn like_pattern(pattern string, escape ?rune) ![]LikeChar {
	runes := pattern.runes()
	mut chars := []LikeChar{cap: runes.len}
	mut i := 0
	for i < runes.len {
		if esc := escape {
			if runes[i] == esc {
				if i + 1 >= runes.len || (runes[i + 1] != `%` && runes[i + 1] != `_`
					&& runes[i + 1] != esc) {
					return sqlstate_22025()
				}
				chars << LikeChar{runes[i + 1], false}
				i += 2
				continue
			}
		}

		chars << LikeChar{runes[i], runes[i] == `%` || runes[i] == `_`}
		i++
	}

	return chars
}

// like_matches reports whether s matches pat, where "%" matches any number of
// characters (including none) and "_" matches exactly one character. All other
// characters must match exactly, so trailing spaces aren't ignored (the
// collation has NO PAD).
//
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, Syntax Rules, 3.d
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules, 3.c and 3.d
fn like_matches(s string, pat []LikeChar) bool {
	chars := s.runes()
	mut i := 0 // position in chars
	mut j := 0 // position in pat

	// When a "%" is found, its position in the pattern and the position in
	// chars it started matching from are remembered. If the rest of the pattern
	// fails to match, the "%" takes one more character and the match is tried
	// again from there.
	mut percent := -1
	mut percent_i := 0

	for i < chars.len {
		if j < pat.len && pat[j].wildcard && pat[j].ch == `%` {
			percent = j
			percent_i = i
			j++
		} else if j < pat.len && ((pat[j].wildcard && pat[j].ch == `_`)
			|| pat[j].ch == chars[i]) {
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
	for j < pat.len && pat[j].wildcard && pat[j].ch == `%` {
		j++
	}

	return j == pat.len
}
