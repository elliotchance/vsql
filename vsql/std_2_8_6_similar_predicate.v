module vsql

// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>
//
// Specify a character string similarity by means of a regular expression.

// SimilarPredicate for "SIMILAR TO" and "NOT SIMILAR TO", with an optional
// "ESCAPE".
struct SimilarPredicate {
	left   RowValueConstructorPredicand
	right  CharacterValueExpression
	escape ?&CharacterValueExpression
	not    bool
}

// SimilarPredicatePart2 is the "SIMILAR TO <pattern>" (or "NOT SIMILAR TO")
// while it's being parsed, before it has the value on the left.
struct SimilarPredicatePart2 {
	right  CharacterValueExpression
	escape ?&CharacterValueExpression
	not    bool
}

fn (e SimilarPredicate) pstr(params map[string]Value) string {
	mut s := e.left.pstr(params)
	if e.not {
		s += ' NOT'
	}
	s += ' SIMILAR TO ${e.right.pstr(params)}'

	if escape := e.escape {
		s += ' ESCAPE ${escape.pstr(params)}'
	}

	return s
}

fn (e SimilarPredicate) compile(mut c Compiler) !CompileResult {
	compiled_l := e.left.compile(mut c)!
	compiled_right := e.right.compile(mut c)!
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

			// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>, General Rules, 4.a
			if left.is_null || right.is_null {
				return new_unknown_value()
			}

			mut escape := ?rune(none)
			if has_escape {
				escape_value := compiled_escape.run(mut conn, data, params)!

				// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>, General
				// Rules, 4.b
				if escape_value.is_null {
					return new_unknown_value()
				}

				escape = escape_character(escape_value)!
			}

			pattern := parse_similar_pattern(right.string_value(), escape)!
			result := pattern.matches(left.string_value())

			if e.not {
				return new_boolean_value(!result)
			}

			return new_boolean_value(result)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_l.contains_agg || compiled_right.contains_agg
			|| compiled_escape.contains_agg
	}
}

enum RegularKind {
	character   // a single character
	any         // "_"
	percent     // "%"
	set         // "[...]"
	sequence    // factors that must match one after the other
	alternation // "|"
	repeat      // "*", "+", "?" or "{m,n}"
}

// RegularNode is one part of a parsed <regular expression>.
struct RegularNode {
	kind     RegularKind
	ch       rune
	children []RegularNode
	set      RegularSet
	// min and max are the number of times the child of a repeat must match. A
	// max of -1 has no limit.
	min int
	max int
}

// RegularSet is a <regular character set>, such as "[a-z]", "[^0-9]" or
// "[[:ALPHA:]^x]".
struct RegularSet {
	negated bool
	include []RegularRange
	exclude []RegularRange
}

// RegularRange is a <character enumeration>: a single character (from and to
// are the same), a range of characters or a named class such as "ALPHA".
struct RegularRange {
	from  rune
	to    rune
	class string
}

// The characters that have a special meaning in a <regular expression>, unless
// they are an <escaped character> (8.6 Syntax Rules 5 and 6).
const regular_special_characters = [`[`, `]`, `(`, `)`, `|`, `^`, `-`, `+`, `*`, `_`, `%`, `?`,
	`{`]

struct RegularParser {
	pattern []rune
	// escaped is true for each character of pattern that was an <escaped
	// character>, so it only stands for itself.
	escaped []bool
	escape  ?rune
	// unescaped_escape is true if the escape character is in pattern other
	// than in an <escaped character>.
	unescaped_escape bool
mut:
	pos int
	// has_class is true once a <regular character set identifier> (such as
	// "[:ALPHA:]") has been parsed.
	has_class bool
}

// parse_similar_pattern parses the pattern of a SIMILAR TO, or returns a
// SQLSTATE 2201B error if it's not a valid <regular expression> (8.6 General
// Rule 2). With an escape character, the escape character followed by a
// special character (or itself) is that character, see regular_special_characters.
fn parse_similar_pattern(pattern string, escape ?rune) !RegularNode {
	// The zero-length pattern only matches the zero-length string (8.6
	// General Rule 7u).
	if pattern == '' {
		return RegularNode{
			kind: .sequence
		}
	}

	if esc := escape {
		// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>, General Rules, 3.c
		//
		// With ":" as the escape character, the ":]" of "[:ALPHA:]" would be
		// an escaped "]", so the class is found by parsing the pattern as if it
		// had no escape character.
		if esc == `:` && regular_pattern_has_class(pattern) {
			return sqlstate_2200b()
		}
	}

	mut p := new_regular_parser(pattern, escape)
	node := p.parse_expression()!

	// For example, an unmatched ")".
	if p.pos < p.pattern.len {
		return sqlstate_2201b()
	}

	// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>, General Rules, 3.b
	if esc := escape {
		if p.unescaped_escape && esc in regular_special_characters {
			return sqlstate_2200c()
		}
	}

	return node
}

// new_regular_parser finds the <escaped character>s in pattern: the escape
// character followed by one of regular_special_characters, or by itself.
fn new_regular_parser(pattern string, escape ?rune) RegularParser {
	runes := pattern.runes()
	mut chars := []rune{cap: runes.len}
	mut escaped := []bool{cap: runes.len}
	mut unescaped_escape := false
	mut i := 0
	for i < runes.len {
		if esc := escape {
			if runes[i] == esc {
				if i + 1 < runes.len && (runes[i + 1] in regular_special_characters
					|| runes[i + 1] == esc) {
					chars << runes[i + 1]
					escaped << true
					i += 2
					continue
				}
				unescaped_escape = true
			}
		}

		chars << runes[i]
		escaped << false
		i++
	}

	return RegularParser{
		pattern:          chars
		escaped:          escaped
		escape:           escape
		unescaped_escape: unescaped_escape
	}
}

// regular_pattern_has_class reports whether pattern is a valid <regular
// expression> (without an escape character) that has a <regular character set
// identifier>, such as "[:ALPHA:]".
fn regular_pattern_has_class(pattern string) bool {
	mut p := new_regular_parser(pattern, none)
	p.parse_expression() or { return false }

	return p.pos == p.pattern.len && p.has_class
}

// next_is reports whether the next character is ch, and not an <escaped
// character>.
fn (p RegularParser) next_is(ch rune) bool {
	return p.pos < p.pattern.len && !p.escaped[p.pos] && p.pattern[p.pos] == ch
}

fn (mut p RegularParser) expect(ch rune) ! {
	if p.next_is(ch) {
		p.pos++
		return
	}

	return sqlstate_2201b()
}

// <regular expression> ::= <regular term> | <regular expression> "|" <regular term>
fn (mut p RegularParser) parse_expression() !RegularNode {
	mut terms := [p.parse_term()!]
	for p.next_is(`|`) {
		p.pos++
		terms << p.parse_term()!
	}

	if terms.len == 1 {
		return terms[0]
	}

	return RegularNode{
		kind:     .alternation
		children: terms
	}
}

// <regular term> ::= <regular factor> | <regular term> <regular factor>
fn (mut p RegularParser) parse_term() !RegularNode {
	mut factors := []RegularNode{}
	for p.pos < p.pattern.len && !p.next_is(`|`) && !p.next_is(`)`) {
		factors << p.parse_factor()!
	}

	// A term must have at least one factor, so "a|" and "()" are not valid.
	if factors.len == 0 {
		return sqlstate_2201b()
	}

	if factors.len == 1 {
		return factors[0]
	}

	return RegularNode{
		kind:     .sequence
		children: factors
	}
}

// <regular factor> ::= <regular primary> [ "*" | "+" | "?" | <repeat factor> ]
fn (mut p RegularParser) parse_factor() !RegularNode {
	primary := p.parse_primary()!

	if p.pos >= p.pattern.len || p.escaped[p.pos] {
		return primary
	}

	mut min, mut max := 0, 0
	match p.pattern[p.pos] {
		`*` {
			min, max = 0, -1
		}
		`+` {
			min, max = 1, -1
		}
		`?` {
			min, max = 0, 1
		}
		`{` {
			min, max = p.parse_repeat_factor()!
			return RegularNode{
				kind:     .repeat
				children: [primary]
				min:      min
				max:      max
			}
		}
		else {
			return primary
		}
	}

	p.pos++

	return RegularNode{
		kind:     .repeat
		children: [primary]
		min:      min
		max:      max
	}
}

// <repeat factor> ::= "{" <low value> [ "," [ <high value> ] ] "}"
fn (mut p RegularParser) parse_repeat_factor() !(int, int) {
	p.expect(`{`)!
	low := p.parse_unsigned_integer()!
	mut high := low
	if p.next_is(`,`) {
		p.pos++
		high = if p.next_is(`}`) { -1 } else { p.parse_unsigned_integer()! }
	}
	p.expect(`}`)!

	// The low value must be positive and the high value can't be less than
	// it (8.6 Syntax Rule 7).
	if low < 1 || (high != -1 && high < low) {
		return sqlstate_2201b()
	}

	return low, high
}

fn (mut p RegularParser) parse_unsigned_integer() !int {
	start := p.pos
	for p.pos < p.pattern.len && !p.escaped[p.pos] && p.pattern[p.pos] >= `0`
		&& p.pattern[p.pos] <= `9` {
		p.pos++
	}

	// Very large values are not valid because they can't be stored.
	if p.pos == start || p.pos - start > 9 {
		return sqlstate_2201b()
	}

	return p.pattern[start..p.pos].string().int()
}

// <regular primary> ::= <character specifier> | "%" | <regular character set>
//   | "(" <regular expression> ")"
fn (mut p RegularParser) parse_primary() !RegularNode {
	if p.pos >= p.pattern.len {
		return sqlstate_2201b()
	}
	if p.escaped[p.pos] {
		return RegularNode{
			kind: .character
			ch:   p.parse_character_specifier()!
		}
	}

	match p.pattern[p.pos] {
		`%` {
			p.pos++
			return RegularNode{
				kind: .percent
			}
		}
		`_` {
			p.pos++
			return RegularNode{
				kind: .any
			}
		}
		`(` {
			p.pos++
			node := p.parse_expression()!
			p.expect(`)`)!
			return node
		}
		`[` {
			return RegularNode{
				kind: .set
				set:  p.parse_set()!
			}
		}
		else {
			return RegularNode{
				kind: .character
				ch:   p.parse_character_specifier()!
			}
		}
	}
}

// <character specifier> is an <escaped character>, or any character other than
// the escape character and the ones that have a special meaning (8.6 Syntax
// Rules 5 and 6).
fn (mut p RegularParser) parse_character_specifier() !rune {
	if p.pos >= p.pattern.len {
		return sqlstate_2201b()
	}
	ch := p.pattern[p.pos]
	is_escape := if esc := p.escape { ch == esc } else { false }
	if !p.escaped[p.pos] && (ch in regular_special_characters || is_escape) {
		return sqlstate_2201b()
	}
	p.pos++

	return ch
}

// <regular character set> ::= "[" <character enumeration>... "]"
//   | "[" "^" <character enumeration>... "]"
//   | "[" <character enumeration include>... "^" <character enumeration exclude>... "]"
fn (mut p RegularParser) parse_set() !RegularSet {
	p.expect(`[`)!

	mut negated := false
	if p.next_is(`^`) {
		p.pos++
		negated = true
	}

	include := p.parse_enumerations()!
	mut exclude := []RegularRange{}
	if !negated && p.next_is(`^`) {
		p.pos++
		exclude = p.parse_enumerations()!
	}

	p.expect(`]`)!

	return RegularSet{negated, include, exclude}
}

// parse_enumerations reads one or more <character enumeration>s.
fn (mut p RegularParser) parse_enumerations() ![]RegularRange {
	mut ranges := []RegularRange{}
	for p.pos < p.pattern.len && !p.next_is(`]`) && !p.next_is(`^`) {
		// "[:ALPHA:]" and the other named classes (8.6 Syntax Rule 3).
		if p.next_is(`[`) {
			p.pos++
			p.expect(`:`)!
			start := p.pos
			for p.pos < p.pattern.len && !p.next_is(`:`) {
				p.pos++
			}
			class := p.pattern[start..p.pos].string().to_upper()
			p.expect(`:`)!
			p.expect(`]`)!

			if class !in ['ALPHA', 'UPPER', 'LOWER', 'DIGIT', 'ALNUM', 'SPACE', 'WHITESPACE'] {
				return sqlstate_2201b()
			}

			p.has_class = true
			ranges << RegularRange{
				class: class
			}
			continue
		}

		from := p.parse_character_specifier()!
		mut to := from
		if p.next_is(`-`) {
			p.pos++
			to = p.parse_character_specifier()!
		}

		ranges << RegularRange{
			from: from
			to:   to
		}
	}

	if ranges.len == 0 {
		return sqlstate_2201b()
	}

	return ranges
}

// matches reports whether the whole of s is in the regular language of the
// pattern (8.6 General Rule 8).
fn (n RegularNode) matches(s string) bool {
	chars := s.runes()
	mut start := []bool{len: chars.len + 1}
	start[0] = true

	return n.ends(chars, start)[chars.len]
}

// ends returns every position in s that a match of this node can end at, when
// the match starts at any of the positions in starts. Keeping every possible
// position (instead of trying each choice in turn and backtracking) means the
// time taken only grows with the length of the string and the pattern.
fn (n RegularNode) ends(s []rune, starts []bool) []bool {
	mut ends := []bool{len: starts.len}

	match n.kind {
		.character, .any, .set {
			for i in 0 .. s.len {
				if starts[i] && n.matches_character(s[i]) {
					ends[i + 1] = true
				}
			}
		}
		.percent {
			for i in 0 .. starts.len {
				if starts[i] {
					for j in i .. ends.len {
						ends[j] = true
					}
					break
				}
			}
		}
		.sequence {
			ends = starts.clone()
			for child in n.children {
				ends = child.ends(s, ends)
			}
		}
		.alternation {
			for child in n.children {
				child_ends := child.ends(s, starts)
				for i in 0 .. ends.len {
					ends[i] = ends[i] || child_ends[i]
				}
			}
		}
		.repeat {
			child := n.children[0]
			mut current := starts.clone()
			for _ in 0 .. n.min {
				next := child.ends(s, current)
				if next == current {
					// Every further repeat would give the same result.
					break
				}
				current = next.clone()
			}

			ends = current.clone()
			mut repeats := n.min
			for n.max == -1 || repeats < n.max {
				next := child.ends(s, current)
				if next == current || !next.any(it) {
					break
				}
				current = next.clone()
				repeats++

				for i in 0 .. ends.len {
					ends[i] = ends[i] || current[i]
				}
			}
		}
	}

	return ends
}

fn (n RegularNode) matches_character(ch rune) bool {
	return match n.kind {
		.character {
			ch == n.ch
		}
		.any {
			true
		}
		.set {
			if n.set.negated {
				!ranges_contain(n.set.include, ch)
			} else {
				ranges_contain(n.set.include, ch) && !ranges_contain(n.set.exclude, ch)
			}
		}
		else {
			false
		}
	}
}

fn ranges_contain(ranges []RegularRange, ch rune) bool {
	for r in ranges {
		in_range := match r.class {
			'' { ch >= r.from && ch <= r.to }
			'ALPHA' { (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) }
			'UPPER' { ch >= `A` && ch <= `Z` }
			'LOWER' { ch >= `a` && ch <= `z` }
			'DIGIT' { ch >= `0` && ch <= `9` }
			'ALNUM' {
				(ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || (ch >= `0` && ch <= `9`)
			}
			'SPACE' { ch == ` ` }
			// White space is defined in 3.1.6.
			'WHITESPACE' { is_white_space(ch) }
			else { false }
		}

		if in_range {
			return true
		}
	}

	return false
}

// is_white_space is the definition of "white space" in 3.1.6.
fn is_white_space(ch rune) bool {
	return (ch >= 0x09 && ch <= 0x0D) || ch == 0x20 || ch == 0x85 || ch == 0xA0
		|| ch == 0x1680 || (ch >= 0x2000 && ch <= 0x200A) || ch == 0x2028 || ch == 0x2029
		|| ch == 0x202F || ch == 0x205F || ch == 0x3000
}
