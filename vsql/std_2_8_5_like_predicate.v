module vsql

// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>
//
// Specify a pattern-match comparison.

// CharacterLikePredicate for "LIKE" and "NOT LIKE", with an optional
// "ESCAPE". It's also "ILIKE" and "NOT ILIKE" if insensitive is true, which is
// an extension of the standard (V302-01).
struct CharacterLikePredicate {
	left        RowValueConstructorPredicand
	right       CharacterValueExpression
	escape      ?&CharacterValueExpression
	not         bool
	insensitive bool
}

// CharacterLikePredicatePart2 is the "LIKE <pattern>" (or "NOT LIKE") while
// it's being parsed, before it has the value on the left.
struct CharacterLikePredicatePart2 {
	right       CharacterValueExpression
	escape      ?&CharacterValueExpression
	not         bool
	insensitive bool
}

fn ref_character_value_expression(e CharacterValueExpression) &CharacterValueExpression {
	return &e
}

// check_string_operands returns an error if either operand of LIKE or SIMILAR
// TO isn't a character string.
fn check_string_operands(op string, left CompileResult, right CompileResult) ! {
	if !left.typ.typ.is_string() || !right.typ.typ.is_string() {
		return sqlstate_42883('operator does not exist: ${left.typ.typ} ${op} ${right.typ.typ}')
	}
}

// operator is the name of the predicate, for its text and its errors.
fn (e CharacterLikePredicate) operator() string {
	return if e.insensitive { 'ILIKE' } else { 'LIKE' }
}

fn (e CharacterLikePredicate) pstr(params map[string]Value) string {
	mut s := e.left.pstr(params)
	if e.not {
		s += ' NOT'
	}
	s += ' ${e.operator()} ${e.right.pstr(params)}'

	if escape := e.escape {
		s += ' ESCAPE ${escape.pstr(params)}'
	}

	return s
}

// The value, the pattern and the escape character must be character strings.
//
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, Syntax Rules, 1
fn (e CharacterLikePredicate) compile(mut c Compiler) !CompileResult {
	mut compiled_right := e.right.compile(mut c)!
	mut compiled_l := e.left.compile(mut c)!
	mut compiled_escape := if escape := e.escape {
		escape.compile(mut c)!
	} else {
		CompileResult{
			run:          unsafe { nil }
			typ:          Type{}
			contains_agg: false
		}
	}
	has_escape := e.escape != none
	compiled_l, compiled_right, compiled_escape = c.with_pattern_types(compiled_l, compiled_right,
		compiled_escape, has_escape)
	check_string_operands(e.operator(), compiled_l, compiled_right)!
	if has_escape {
		check_string_operands(e.operator(), compiled_l, compiled_escape)!
	}

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

			// The escape character is found in the pattern before it's folded, so
			// it only ever escapes what it's written as.
			pattern := like_pattern(right.string_value(), escape)!
			result := if e.insensitive {
				like_matches(ilike_value(left.string_value()), ilike_pattern(pattern))
			} else {
				like_matches(like_value(left.string_value()), pattern)
			}

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

// LikeValueChar is one character of the value being matched. A case folded
// character can become more than one (ß is "ss"), and each one after the first
// has continues set.
struct LikeValueChar {
	ch        rune
	continues bool
}

// like_value is the characters of s to match with LIKE.
fn like_value(s string) []LikeValueChar {
	return s.runes().map(LikeValueChar{it, false})
}

// ilike_value is the characters of s to match with ILIKE.
fn ilike_value(s string) []LikeValueChar {
	mut chars := []LikeValueChar{cap: s.len}
	for c in s.runes() {
		for i, folded in case_fold(c) {
			chars << LikeValueChar{folded, i > 0}
		}
	}

	return chars
}

// ilike_pattern folds the characters of a LIKE pattern. It must be after
// like_pattern, because a wildcard or an escape character isn't a letter to be
// folded.
fn ilike_pattern(pattern []LikeChar) []LikeChar {
	mut chars := []LikeChar{cap: pattern.len}
	for c in pattern {
		if c.wildcard {
			chars << c
			continue
		}

		for folded in case_fold(c.ch) {
			chars << LikeChar{folded, false}
		}
	}

	return chars
}

// case_fold returns the characters that c is compared as by ILIKE, using the
// same mappings as UPPER and LOWER. Characters are the same if UPPER or LOWER
// makes them the same, so it's LOWER(UPPER(LOWER(c))): the first LOWER is for ẞ,
// which UPPER doesn't change, but LOWER makes it ß, which UPPER makes SS.
fn case_fold(c rune) []rune {
	if c < 0x80 {
		return [if c >= `A` && c <= `Z` { c + 32 } else { c }]
	}

	lower := replace_case_mappings(c.str(), lower_case_mappings)
	upper := replace_case_mappings(lower, upper_case_mappings)

	return replace_case_mappings(upper, lower_case_mappings).runes()
}

// like_matches reports whether chars matches pat, where "%" matches any number
// of characters (including none) and "_" matches exactly one character. All
// other characters must match exactly, so trailing spaces aren't ignored (the
// collation has NO PAD).
//
// A wildcard can't start inside of a character that was folded into several. So
// with ILIKE, 'ß' matches 'SS' and '_' but not 'S%' or 'S_'. This is the same as
// the substrings of the standard, each of which is a number of whole characters
// of the value.
//
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, Syntax Rules, 3.d
// ISO/IEC 9075-2:2016(E), 8.5, <like predicate>, General Rules, 3.c and 3.d
fn like_matches(chars []LikeValueChar, pat []LikeChar) bool {
	mut i := 0 // position in chars
	mut j := 0 // position in pat

	// When a "%" is found, its position in the pattern and the position in
	// chars it started matching from are remembered. If the rest of the pattern
	// fails to match, the "%" takes one more character and the match is tried
	// again from there.
	mut percent := -1
	mut percent_i := 0

	for i < chars.len {
		if j < pat.len && pat[j].wildcard && !chars[i].continues {
			if pat[j].ch == `%` {
				percent = j
				percent_i = i
			} else {
				i = next_like_char(chars, i)
			}
			j++
		} else if j < pat.len && !pat[j].wildcard && pat[j].ch == chars[i].ch {
			i++
			j++
		} else if percent >= 0 {
			percent_i = next_like_char(chars, percent_i)
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

// next_like_char returns the position after the whole character at i.
fn next_like_char(chars []LikeValueChar, i int) int {
	mut next := i + 1
	for next < chars.len && chars[next].continues {
		next++
	}

	return next
}
