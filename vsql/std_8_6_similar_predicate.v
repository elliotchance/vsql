module vsql

// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>
//
// Specify a character string similarity by means of a regular expression.

// SimilarPredicate for "SIMILAR TO" and "NOT SIMILAR TO".
struct SimilarPredicate {
	left  RowValueConstructorPredicand
	right CharacterValueExpression
	not   bool
}

// SimilarPredicatePart2 is the "SIMILAR TO <pattern>" (or "NOT SIMILAR TO")
// while it's being parsed, before it has the value on the left.
struct SimilarPredicatePart2 {
	right CharacterValueExpression
	not   bool
}

fn (e SimilarPredicate) pstr(params map[string]Value) string {
	if e.not {
		return '${e.left.pstr(params)} NOT SIMILAR TO ${e.right.pstr(params)}'
	}

	return '${e.left.pstr(params)} SIMILAR TO ${e.right.pstr(params)}'
}

fn (e SimilarPredicate) compile(mut c Compiler) !CompileResult {
	compiled_l := e.left.compile(mut c)!
	compiled_right := e.right.compile(mut c)!

	return CompileResult{
		run:          fn [e, compiled_l, compiled_right] (mut conn Connection, data Row, params map[string]Value) !Value {
			left := compiled_l.run(mut conn, data, params)!
			right := compiled_right.run(mut conn, data, params)!

			// ISO/IEC 9075-2:2016(E), 8.6, <similar predicate>, General Rules, 4a
			if left.is_null || right.is_null {
				return new_unknown_value()
			}

			pattern := parse_similar_pattern(right.string_value())!
			result := pattern.matches(left.string_value())

			if e.not {
				return new_boolean_value(!result)
			}

			return new_boolean_value(result)
		}
		typ:          new_type('BOOLEAN', 0, 0)
		contains_agg: compiled_l.contains_agg || compiled_right.contains_agg
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

struct RegularParser {
	pattern []rune
mut:
	pos int
}

// parse_similar_pattern parses the pattern of a SIMILAR TO, or returns a
// SQLSTATE 2201B error if it's not a valid <regular expression> (8.6 General
// Rule 2).
fn parse_similar_pattern(pattern string) !RegularNode {
	// The zero-length pattern only matches the zero-length string (8.6
	// General Rule 7u).
	if pattern == '' {
		return RegularNode{
			kind: .sequence
		}
	}

	mut p := RegularParser{
		pattern: pattern.runes()
	}
	node := p.parse_expression()!

	// For example, an unmatched ")".
	if p.pos < p.pattern.len {
		return sqlstate_2201b()
	}

	return node
}

fn (p RegularParser) peek() ?rune {
	if p.pos < p.pattern.len {
		return p.pattern[p.pos]
	}

	return none
}

fn (mut p RegularParser) expect(ch rune) ! {
	if next := p.peek() {
		if next == ch {
			p.pos++
			return
		}
	}

	return sqlstate_2201b()
}

// <regular expression> ::= <regular term> | <regular expression> "|" <regular term>
fn (mut p RegularParser) parse_expression() !RegularNode {
	mut terms := [p.parse_term()!]
	for p.peek() or { 0 } == `|` {
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
	for {
		next := p.peek() or { break }
		if next == `|` || next == `)` {
			break
		}

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

	mut min, mut max := 0, 0
	match p.peek() or { 0 } {
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
	if p.peek() or { 0 } == `,` {
		p.pos++
		high = if p.peek() or { 0 } == `}` { -1 } else { p.parse_unsigned_integer()! }
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
	for p.pos < p.pattern.len && p.pattern[p.pos] >= `0` && p.pattern[p.pos] <= `9` {
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
	ch := p.peek() or { return sqlstate_2201b() }
	match ch {
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

// <character specifier> is any character other than the ones that have a
// special meaning (8.6 Syntax Rule 5).
fn (mut p RegularParser) parse_character_specifier() !rune {
	ch := p.peek() or { return sqlstate_2201b() }
	if ch in [`[`, `]`, `(`, `)`, `|`, `^`, `-`, `+`, `*`, `_`, `%`, `?`, `{`] {
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
	if p.peek() or { 0 } == `^` {
		p.pos++
		negated = true
	}

	include := p.parse_enumerations()!
	mut exclude := []RegularRange{}
	if !negated && p.peek() or { 0 } == `^` {
		p.pos++
		exclude = p.parse_enumerations()!
	}

	p.expect(`]`)!

	return RegularSet{negated, include, exclude}
}

// parse_enumerations reads one or more <character enumeration>s.
fn (mut p RegularParser) parse_enumerations() ![]RegularRange {
	mut ranges := []RegularRange{}
	for {
		next := p.peek() or { break }
		if next == `]` || next == `^` {
			break
		}

		// "[:ALPHA:]" and the other named classes (8.6 Syntax Rule 3).
		if next == `[` {
			p.pos++
			p.expect(`:`)!
			start := p.pos
			for p.pos < p.pattern.len && p.pattern[p.pos] != `:` {
				p.pos++
			}
			class := p.pattern[start..p.pos].string().to_upper()
			p.expect(`:`)!
			p.expect(`]`)!

			if class !in ['ALPHA', 'UPPER', 'LOWER', 'DIGIT', 'ALNUM', 'SPACE', 'WHITESPACE'] {
				return sqlstate_2201b()
			}

			ranges << RegularRange{
				class: class
			}
			continue
		}

		from := p.parse_character_specifier()!
		mut to := from
		if p.peek() or { 0 } == `-` {
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
			mut count := n.min
			for n.max == -1 || count < n.max {
				next := child.ends(s, current)
				if next == current || !next.any(it) {
					break
				}
				current = next.clone()
				count++

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
