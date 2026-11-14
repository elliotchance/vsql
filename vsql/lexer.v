// lexer.v contains the lexer (tokenizer) that convert a SQL string into tokens
// to be read by the parser.v

module vsql

import math.big

// YYSym is the value of a symbol on the parser's stack. Every node of the
// syntax tree is kept in a YYBox (see below), so that YYSym stays small. Only a
// string (the text of a token, like a keyword or a number) and a bool aren't
// boxed, because they're no bigger than a YYBox and are only ever read as
// themselves.
type YYSym = YYBox | bool | string

// YYSymType is the yacc internal type for the stack that contains the symbols
// to reduce (pass to the code). The only requirement here is that `yys` is
// included as it contains the position of the token.
// yy_as is used by the grammar actions instead of `as` (see
// scripts/generate-grammar.vsh). V3 expands every `as` on a sum type into a
// check for each variant, so having one function for each type keeps the
// parser small.
fn yy_as[T](sym YYSym) T {
	if sym is T {
		return sym
	}

	panic('expected ${T.name}')
}

// YYBox holds a node of the syntax tree on the heap. A sum type is as big as
// its biggest type, and the parser copies a YYSymType for every token and every
// rule it reduces, so every node (even a small one, so that no one has to decide
// which are big enough) is boxed, and a YYSymType is only a few words. The
// grammar actions use yy_box to make one, and yy_unbox (generated for any type
// that is not in YYSym, see scripts/generate-grammar.vsh) to get it back.
struct YYBox {
	typ int
	ptr voidptr
}

fn yy_box[T](v T) YYBox {
	mut ptr := unsafe { &T(voidptr(malloc(int(sizeof(T))))) }
	unsafe {
		*ptr = v
	}
	return YYBox{typeof[T]().idx, voidptr(ptr)}
}

fn yy_unbox[T](sym YYSym) T {
	if sym is YYBox {
		if sym.typ == typeof[T]().idx {
			return unsafe { *(&T(sym.ptr)) }
		}
	}

	panic('expected ${T.name}')
}

// yy_stmt returns the statement that was parsed. It isn't generic so that the
// result is known to be a Stmt (V doesn't always know that the result of
// yy_unbox[Stmt] is a sum type).
fn yy_stmt(sym YYSym) Stmt {
	return yy_unbox[Stmt](sym)
}

struct YYSymType {
mut:
	v   YYSym
	yys int
}

struct Lexer {
mut:
	tokens []Token
	pos    int
	// features are the features outside of Core SQL that the parsed statement
	// uses (see flag).
	features []string
	// sort_key_parts and sort_key_starts find what each <sort key> contains (see
	// flag_sort_key).
	sort_key_parts  []SortKeyPart
	sort_key_starts []int
	// source is the text that the tokens are from, if it's known. A syntax error
	// then says where it is (see syntax_error_position).
	source string
	// at_end is true once the parser has been given the end of the tokens.
	at_end bool
}

fn (mut l Lexer) lex(mut lval YYSymType) int {
	if l.pos >= l.tokens.len {
		l.at_end = true
		return 0
	}

	l.pos++
	unsafe {
		*lval = l.tokens[l.pos - 1].sym()
	}
	return l.tokens[l.pos - 1].token
}

fn (mut l Lexer) error(s string) IError {
	msg := cleanup_yacc_error(s)
	if l.source == '' {
		return sqlstate_42601(msg)
	}

	// The token that the parser didn't expect is the last one it was given, or
	// the end.
	index := if l.at_end { l.tokens.len } else { l.pos - 1 }

	return sqlstate_42601(describe_syntax_error(msg, l.source, l.tokens, index))
}

fn cleanup_yacc_error(s string) string {
	mut msg := s

	msg = msg.replace('OPERATOR_ILIKE', 'ILIKE')
	msg = msg.replace('OPERATOR_COMMA', '","')
	msg = msg.replace('OPERATOR_RIGHT_PAREN', '")"')
	msg = msg.replace('OPERATOR_DOUBLE_PIPE', '"||"')
	msg = msg.replace('OPERATOR_PLUS', '"+"')
	msg = msg.replace('OPERATOR_MINUS', '"-"')
	msg = msg.replace('OPERATOR_SEMICOLON', '";"')
	msg = msg.replace('OPERATOR_EQUALS', '"="')
	msg = msg.replace('OPERATOR_LEFT_PAREN', '"("')
	msg = msg.replace('OPERATOR_ASTERISK', '"*"')
	msg = msg.replace('OPERATOR_PERIOD', '"."')
	msg = msg.replace('OPERATOR_SOLIDUS', '"/"')
	msg = msg.replace('OPERATOR_DOUBLE_COLON', '"::"')
	msg = msg.replace('OPERATOR_COLON', '":"')
	msg = msg.replace('OPERATOR_QUESTION_MARK', '"?"')
	msg = msg.replace('OPERATOR_LESS_THAN', '"<"')
	msg = msg.replace('OPERATOR_GREATER_THAN', '">"')
	msg = msg.replace('OPERATOR_NOT_EQUALS', '"<>"')
	msg = msg.replace('OPERATOR_BANG_EQUALS', '"!="')
	msg = msg.replace('OPERATOR_GREATER_EQUALS', '">="')
	msg = msg.replace('OPERATOR_LESS_EQUALS', '"<="')
	msg = msg.replace('OPERATOR_PERIOD_ASTERISK', '"." "*"')
	msg = msg.replace('OPERATOR_LEFT_PAREN_ASTERISK', '"(" "*"')

	msg = msg.replace('LITERAL_IDENTIFIER', 'identifier')
	msg = msg.replace('LITERAL_STRING', 'string')
	msg = msg.replace('LITERAL_NUMBER', 'number')

	return msg['syntax error: '.len..]
}

// A TokenValue is what a token has besides its number. It's only the types that
// a token can have, rather than YYSym, because a sum type is as big as its
// biggest type, and YYSym is as big as the biggest node of the syntax tree.
type TokenValue = IdentifierChain | Value | string

// Token is a token of a statement. start and end are where it is in the text
// that was tokenized, as the positions of its first character and the
// character after it (see syntax_error_position).
struct Token {
	token int
	value TokenValue
mut:
	start int
	end   int
}

// sym is the value of the token for the parser.
fn (t Token) sym() YYSymType {
	return YYSymType{
		v: match t.value {
			IdentifierChain { YYSym(yy_box[IdentifierChain](t.value)) }
			Value { YYSym(yy_box[Value](t.value)) }
			string { YYSym(t.value) }
		}
	}
}

fn tokenize(sql_stmt string) ![]Token {
	tokens, _ := tokenize_with_features(sql_stmt)!

	return tokens
}

// tokenize_with_features also returns the features outside of Core SQL that
// the tokens use (see flag), which the parser can't see: F271 for a compound
// character literal, F393 for a Unicode character string literal, T351 for a
// bracketed comment, T661 for a hexadecimal, octal or binary integer and T662
// for an underscore in a number.
//
// ISO/IEC 9075-2:2023, 5.2, <token> and <separator>, Conformance Rules, 3
// ISO/IEC 9075-2:2023, 5.3, <literal>, Conformance Rules, 6, 11, 12 and 13
fn tokenize_with_features(sql_stmt string) !([]Token, []string) {
	mut tokens := []Token{}
	mut features := []string{}
	text := sql_stmt.trim(';')
	cs := statement_runes(text)
	// If every character is ASCII, the position of a character in cs is also its
	// position in text, so a token is a slice of text rather than being encoded
	// again from its runes (see substring).
	ascii := cs.len == text.len
	// The positions of the tokens are in sql_stmt, before the semicolons at the
	// start are trimmed.
	offset := sql_stmt.len - sql_stmt.trim_left(';').len
	mut i := 0
	mut dynamic_parameters := 0

	for i < cs.len {
		// A comment is a separator, the same as a space.
		if is_comment(cs, i) {
			if cs[i] == `/` {
				features << 'T351'
			}
			i = skip_comment(cs, i)!
			continue
		}

		// Every token that is found from here (there can be more than one, such
		// as "1E") is given the position from start to i.
		start_tokens := tokens.len
		first_position := offset + i

		// ISO/IEC 9075-2:2023, 6.4, <value specification> and <target
		// specification>
		//
		// Each <dynamic parameter specification> ("?") is named by its
		// position: "?1", "?2", etc.
		if cs[i] == `?` {
			dynamic_parameters++
			tokens << Token{token_operator_question_mark, '?${dynamic_parameters}', offset + i, offset + i + 1}
			i++
			continue
		}

		// Numbers. A hexadecimal, octal or binary integer (T661) is a number
		// token of its decimal value, and can't be part of an exact numeric
		// literal with a period or the mantissa of an approximate one.
		//
		// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 32
		if radix := non_decimal_radix(cs, i) {
			word, end := read_non_decimal_integer(cs, i, radix)!
			if word.contains('_') {
				features << 'T662'
			}
			features << 'T661'
			i = end
			if (i < cs.len && cs[i] == `.`) || is_exponent(cs, i) {
				return sqlstate_42601('a non-decimal integer cannot have a period or exponent: ${cs[first_position - offset..i + 1].string()}')
			}
			tokens << Token{token_literal_number, non_decimal_integer_value(word, radix)!, 0, 0}
			unsafe {
				goto next
			}
		}
		if cs[i] >= `0` && cs[i] <= `9` {
			start := i
			i = end_of_decimal_integer(cs, i)
			mut word := substring(text, cs, ascii, start, i)
			if word.contains('_') {
				features << 'T662'
				word = word.replace('_', '')
			}
			tokens << Token{token_literal_number, word, 0, 0}

			// There is a special case for approximate numbers where 'E' is considered
			// a separate token in the SQL BNF. However, "e2" should not be treated as
			// two tokens, but rather we need to catch this case only when with a
			// number token. The literal is a single token (5.2 Syntax Rule 5), so the
			// exponent must follow the E without any spaces. A mantissa may also end
			// with a period, such as "1.e5".
			if is_exponent(cs, i + 1) && cs[i] == `.` {
				tokens << Token{token_operator_period, '.', 0, 0}
				i++
			}
			if is_exponent(cs, i) {
				tokens << Token{token_e, '', 0, 0}
				i++
			}

			unsafe {
				goto next
			}
		}

		// Strings, including a Unicode string like U&'\0041' (5.3). The U may be
		// lower case, but there must not be a space before the quote (5.3 Syntax
		// Rules 3 and 11).
		is_unicode := i + 2 < cs.len && (cs[i] == `U` || cs[i] == `u`) && cs[i + 1] == `&`
			&& cs[i + 2] == `'`
		if cs[i] == `'` || is_unicode {
			if is_unicode {
				i += 2
			}
			mut word, end, literal_features := read_string_literal(cs, i)!
			i = end
			features << literal_features
			if is_unicode {
				features << 'F393'
				escape, escape_end := read_unicode_escape_specifier(cs, i)!
				i = escape_end
				word = unescape_unicode(word, escape)!
			}
			check_noncharacters(word)!
			// The character repertoire is always UCS, so the value is normalized
			// (5.3 General Rule 2), after a compound literal is put together.
			tokens << Token{token_literal_string, new_character_value(normalize_nfc(word)), 0, 0}
			unsafe {
				goto next
			}
		}

		// Delimited identifiers. The body must have at least one character (5.2).
		// A doubled quote ("") is a quote character in the name, but it's kept
		// doubled here so that split_identifier_parts can find the end of each
		// part of the chain.
		if cs[i] == `"` {
			start := i
			mut word := ''
			i++
			for {
				if i >= cs.len {
					return sqlstate_42601('unterminated delimited identifier: ${cs[start..].string()}')
				}
				if cs[i] == `"` {
					if i + 1 < cs.len && cs[i + 1] == `"` {
						word += '""'
						i += 2
						continue
					}
					break
				}
				word += '${cs[i]}'
				i++
			}
			if word == '' {
				return sqlstate_42601('a delimited identifier cannot be empty')
			}
			i++
			tokens << Token{token_literal_identifier, IdentifierChain{
				identifier: '"${word}"'
			}, 0, 0}
			unsafe {
				goto next
			}
		}

		// Operators
		if i < cs.len - 1 {
			multi_token := multi_operator_token(cs[i], cs[i + 1])
			if multi_token != 0 {
				tokens << Token{multi_token, substring(text, cs, ascii, i, i + 2), 0, 0}
				i += 2
				unsafe {
					goto next
				}
			}
		}

		single_token := single_operator_token(cs[i])
		if single_token != 0 {
			tokens << Token{single_token, substring(text, cs, ascii, i, i + 1), 0, 0}
			i++
			unsafe {
				goto next
			}
		}

		// Keyword or regular identifier
		word_start := i
		mut is_not_first := false
		for i < cs.len && is_identifier_char(cs[i], is_not_first) {
			i++
			is_not_first = true
		}
		word := substring(text, cs, ascii, word_start, i)

		// A character that doesn't start a token must be a separator.
		//
		// ISO/IEC 9075-2:2023, 5.2, <token> and <separator>, Syntax Rules, 3
		if word == '' {
			if !is_white_space(cs[i]) {
				return sqlstate_42601('invalid character: ${cs[i]}')
			}
			i++
			continue
		}

		upper_word := word.to_upper()
		// E is only a token directly after a number (see above), otherwise it's a
		// regular identifier. LIMIT is the same (see is_limit_clause).
		tok_number := keyword_tokens[upper_word] or { 0 }
		if tok_number != 0 && upper_word != 'E' && upper_word != 'LIMIT' {
			tokens << Token{tok_number, upper_word, 0, 0}
		} else {
			tokens << Token{token_literal_identifier, IdentifierChain{
				identifier: word
			}, 0, 0}
		}

		next: for j in start_tokens .. tokens.len {
			tokens[j].start = first_position
			tokens[j].end = offset + i
		}
		length, new_token := tail_substitution(tokens)
		if length > 0 {
			start := tokens[tokens.len - length].start
			end := tokens[tokens.len - 1].end
			tokens = tokens[..tokens.len - length].clone()
			tokens << Token{new_token, '', start, end}
		}
	}

	for position, token in tokens {
		if token.token == token_ilike && is_ilike_operator(tokens, position) {
			tokens[position] = Token{token_operator_ilike, token.value, token.start, token.end}
		}
	}

	for pos in 0 .. tokens.len {
		if is_limit_clause(tokens, pos) {
			tokens[pos] = Token{token_limit, 'LIMIT', tokens[pos].start, tokens[pos].end}
		}
	}

	return tokens, features
}

// statement_runes is text.runes(), but an ASCII statement is copied straight
// into the runes, rather than decoding and appending one character at a time.
@[direct_array_access]
fn statement_runes(text string) []rune {
	mut cs := []rune{len: text.len}
	for i in 0 .. text.len {
		if text[i] >= 0x80 {
			return text.runes()
		}
		cs[i] = rune(text[i])
	}

	return cs
}

// substring is the characters from start to end (not including end) of the
// text that the runes cs are from. If the text is ASCII, the positions are the
// same in both, so it's a slice of the text.
@[inline]
fn substring(text string, cs []rune, ascii bool, start int, end int) string {
	if ascii {
		return text[start..end]
	}

	return cs[start..end].string()
}

// is_ilike_operator reports whether the word ILIKE at tokens[i] is the operator
// rather than a name. ILIKE isn't a word of the standard, so existing SQL can use
// it as a name, including as an alias without AS. The parser can't choose between
// those from one token: "x ILIKE FROM" has an alias and "x ILIKE y" doesn't. So
// it's the operator only if it's after the end of a value (or that and NOT), and
// before the start of one.
//
// The other case that looks like that is an alias with a column list, in "FROM t
// ILIKE (a, b)", which is allowed by correlation_or_recognition.
fn is_ilike_operator(tokens []Token, i int) bool {
	if i == 0 || i + 1 == tokens.len {
		return false
	}

	reserved := reserved_words()
	before := if tokens[i - 1].token == token_not && i > 1 { i - 2 } else { i - 1 }

	return ends_value(tokens[before], reserved) && starts_value(tokens[i + 1], reserved)
}

// ends_value reports whether a value can end with the token. All names and
// literals do, but not most of the reserved words, which can be before a name.
// Neither do the only non-reserved words that are before a name in the grammar,
// so a column that's called one of those needs quotes to be the left of ILIKE.
fn ends_value(token Token, reserved []string) bool {
	name := yy_toknames[token.token - 57343]
	if name.starts_with('OPERATOR_') {
		return name in ['OPERATOR_RIGHT_PAREN', 'OPERATOR_QUESTION_MARK']
	}

	if name in ['ADD', 'CONNECTION', 'CONSTRAINTS', 'SCHEMA', 'SEQUENCE'] {
		return false
	}

	return name !in reserved
		|| name in ['CURRENT_CATALOG', 'CURRENT_SCHEMA', 'END', 'FALSE', 'TRUE', 'UNKNOWN']
}

// starts_value reports whether the pattern of ILIKE can start with the token. All
// names and literals do, but only the reserved words that can be a character
// string. A pattern of any other type is an error anyway.
fn starts_value(token Token, reserved []string) bool {
	name := yy_toknames[token.token - 57343]
	if name.starts_with('OPERATOR_') {
		return name in ['OPERATOR_LEFT_PAREN', 'OPERATOR_QUESTION_MARK']
	}

	return name !in reserved || name in ['CASE', 'CAST', 'COALESCE', 'CURRENT_CATALOG', 'CURRENT_SCHEMA',
		'LOWER', 'MAX', 'MIN', 'NULLIF', 'SUBSTRING', 'TRIM', 'UPPER']
}

// is_limit_clause returns true if tokens[i] is the regular identifier LIMIT and
// it starts a limit_clause rather than being a name, such as a column or an
// alias (with or without AS). The parser can't tell them apart because it only
// sees the next token, and "FROM t limit" can be followed by anything that
// follows a table. An identifier is never followed by something that starts a
// row count, so that decides it.
//
// The exception is a sign, because "limit - 1" can be an expression. However,
// that needs an operand to be expected, and a limit_clause can't be there since
// the query isn't finished. So it's a limit_clause unless the token before it
// is one that an expression can directly follow in the grammar, or a period for
// "t.limit - 1".
fn is_limit_clause(tokens []Token, i int) bool {
	sym := tokens[i].value
	if tokens[i].token != token_literal_identifier || sym !is IdentifierChain
		|| (sym as IdentifierChain).identifier.to_upper() != 'LIMIT' || i + 1 >= tokens.len {
		return false
	}

	next := tokens[i + 1].token
	after := if i + 2 < tokens.len { tokens[i + 2].token } else { 0 }
	if next in [token_operator_plus, token_operator_minus] {
		return i > 0 && (after == token_literal_number || after == token_operator_period)
			&& tokens[i - 1].token !in [
				token_all,
				token_and,
				token_asymmetric,
				token_between,
				token_by,
				token_case,
				token_distinct,
				token_else,
				token_for,
				token_from,
				token_having,
				token_not,
				token_on,
				token_operator_asterisk,
				token_operator_bang_equals,
				token_operator_comma,
				token_operator_equals,
				token_operator_greater_equals,
				token_operator_greater_than,
				token_operator_left_paren,
				token_operator_less_equals,
				token_operator_less_than,
				token_operator_minus,
				token_operator_not_equals,
				token_operator_period,
				token_operator_plus,
				token_operator_solidus,
				token_or,
				token_select,
				token_symmetric,
				token_then,
				token_values,
				token_when,
				token_where,
			]
	}

	// DATE, TIME and TIMESTAMP are also data types: "limit DATE" is a column.
	if next in [token_date, token_time, token_timestamp] {
		return after == token_literal_string
	}

	// A number can start with a period, but "limit.x" is a qualified name.
	if next == token_operator_period {
		return after == token_literal_number
	}

	return next in [token_literal_number, token_literal_string, token_true, token_false, token_unknown]
}

// read_string_literal returns the characters of the string that starts with
// the quote at cs[i], and the position after it. A doubled quote ('') is a
// single quote. Strings that are only separated by spaces that include a new
// line are one string, so 'ab' is the same as:
//
//   'a'
//   'b'
//
// A string without a closing quote is a syntax error. The last value is the
// features of a string with more than one part (a compound literal), including
// the separators between the parts. See tokenize_with_features.
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 1, 2 and 7
fn read_string_literal(cs []rune, start int) !(string, int, []string) {
	mut word := ''
	mut i := start + 1
	for {
		if i >= cs.len {
			return sqlstate_42601('unterminated string: ${cs[start..].string()}')
		}
		if cs[i] == `'` {
			// A doubled quote ('') represents a single quote character.
			if i + 1 < cs.len && cs[i + 1] == `'` {
				word += "'"
				i += 2
				continue
			}
			break
		}
		word += '${cs[i]}'
		i++
	}
	i++

	mut j := i
	mut has_newline := false
	mut separator_features := []string{}
	for j < cs.len {
		if is_comment(cs, j) {
			end := skip_comment(cs, j)!
			has_newline = has_newline || cs[j..end].contains(`\n`)
			if cs[j] == `/` {
				separator_features << 'T351'
			}
			j = end
		} else if is_white_space(cs[j]) {
			has_newline = has_newline || cs[j] == `\n`
			j++
		} else {
			break
		}
	}
	if has_newline && j < cs.len && cs[j] == `'` {
		next_word, end, next_features := read_string_literal(cs, j)!
		separator_features << 'F271'
		separator_features << next_features
		return word + next_word, end, separator_features
	}

	return word, i, []string{}
}

// is_comment returns true if a comment starts at cs[i]. A simple comment
// starts with two (or more) minus signs and continues to the end of the line. A
// bracketed comment starts with "/*" and ends with the matching "*/". So
// "1--1" is 1 followed by a comment, a subtraction of a negative number needs a
// separator ("1 - -1").
//
// ISO/IEC 9075-2:2023, 5.2, <token> and <separator>
// ISO/IEC 9075-2:2023, 6.30, <numeric value expression>, Syntax Rules, 4
fn is_comment(cs []rune, i int) bool {
	return i + 1 < cs.len && ((cs[i] == `-` && cs[i + 1] == `-`)
		|| (cs[i] == `/` && cs[i + 1] == `*`))
}

// skip_comment returns the position after the comment that starts at cs[i]. A
// simple comment ends at the new line (or the end of the SQL), which isn't part
// of it.
//
// A "/*" inside a bracketed comment starts a nested bracketed comment (Syntax
// Rule 10), so each one needs its own "*/".
fn skip_comment(cs []rune, start int) !int {
	mut i := start
	if cs[i] == `-` {
		for i < cs.len && cs[i] != `\n` {
			i++
		}
		return i
	}

	mut depth := 0
	for i + 1 < cs.len {
		if cs[i] == `/` && cs[i + 1] == `*` {
			depth++
			i += 2
		} else if cs[i] == `*` && cs[i + 1] == `/` {
			depth--
			i += 2
			if depth == 0 {
				return i
			}
		} else {
			i++
		}
	}

	return sqlstate_42601('unterminated comment: ${cs[start..].string()}')
}

// skip_separators returns the position after the white space and comments that
// start at cs[i], which may be none of them.
//
// ISO/IEC 9075-2:2023, 5.2, <token> and <separator>
fn skip_separators(cs []rune, start int) !int {
	mut i := start
	for i < cs.len {
		if is_comment(cs, i) {
			i = skip_comment(cs, i)!
		} else if is_white_space(cs[i]) {
			i++
		} else {
			break
		}
	}

	return i
}

// read_unicode_escape_specifier returns the escape character of a Unicode
// string, from the optional UESCAPE '<character>' after the string at cs[i],
// and the position after it. Otherwise, the escape character is a backslash.
//
// ISO/IEC 9075-2:2023, 5.2, <token> and <separator>, Syntax Rules, 17 to 18
fn read_unicode_escape_specifier(cs []rune, start int) !(rune, int) {
	mut i := skip_separators(cs, start)!
	if i + 7 > cs.len || cs[i..i + 7].string().to_upper() != 'UESCAPE'
		|| (i + 7 < cs.len && is_identifier_char(cs[i + 7], true)) {
		return `\\`, start
	}

	i = skip_separators(cs, i + 7)!
	if i + 2 >= cs.len || cs[i] != `'` || cs[i + 2] != `'` {
		return sqlstate_42601('UESCAPE must be followed by a single character in quotes')
	}

	escape := cs[i + 1]
	if is_hexit(escape) || escape in [`+`, `'`, `"`] || is_white_space(escape) {
		return sqlstate_42601("invalid Unicode escape character: '${escape}'")
	}

	return escape, i + 3
}

// unescape_unicode replaces each escape in a Unicode string: the escape
// character followed by 4 hexits (such as \0041 for A), a plus and 6 hexits
// (such as \+01F600), or another escape character (for the escape character
// itself).
//
// ISO/IEC 9075-2:2023, 5.2, <token> and <separator>, Syntax Rules, 20 to 23
fn unescape_unicode(s string, escape rune) !string {
	cs := s.runes()
	mut result := []rune{}
	mut i := 0
	for i < cs.len {
		if cs[i] != escape {
			result << cs[i]
			i++
			continue
		}

		if i + 1 < cs.len && cs[i + 1] == escape {
			result << escape
			i += 2
			continue
		}

		start, digits := if i + 1 < cs.len && cs[i + 1] == `+` { i + 2, 6 } else { i + 1, 4 }
		if start + digits > cs.len || !cs[start..start + digits].all(is_hexit(it)) {
			return sqlstate_42601('invalid Unicode escape: ${cs[i..].string()}')
		}

		mut code_point := u32(0)
		for c in cs[start..start + digits] {
			code_point = code_point * 16 + u32(hexit_value(c))
		}
		if code_point > 0x10FFFF || (code_point >= 0xD800 && code_point <= 0xDFFF) {
			return sqlstate_42601('invalid Unicode code point: ${cs[i..start + digits].string()}')
		}

		result << rune(code_point)
		i = start + digits
	}

	return result.string()
}

// end_of_decimal_integer returns the position after the <unsigned decimal
// integer> that starts at i. An underscore can be between two digits (T662),
// but not at the end or next to another underscore, so "1_000" ends after the
// last 0, and "1__0" and "1_" end after the 1.
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 22
fn end_of_decimal_integer(cs []rune, start int) int {
	mut i := start
	for i < cs.len {
		if cs[i] >= `0` && cs[i] <= `9` {
			i++
		} else if cs[i] == `_` && i + 1 < cs.len && cs[i + 1] >= `0` && cs[i + 1] <= `9` {
			i += 2
		} else {
			break
		}
	}

	return i
}

// non_decimal_radix returns the radix (16, 8 or 2) if an <unsigned hexadecimal
// integer>, <unsigned octal integer> or <unsigned binary integer> starts at i.
// That's "0X", "0O" or "0B" (in either case), directly followed by a digit of
// the radix, or an underscore and a digit. Otherwise it's an ordinary 0, such as
// "0x" (0 followed by the name x).
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 26 and 27
fn non_decimal_radix(cs []rune, i int) ?u32 {
	if cs[i] != `0` || i + 1 >= cs.len {
		return none
	}
	radix := match cs[i + 1] {
		`x`, `X` { u32(16) }
		`o`, `O` { u32(8) }
		`b`, `B` { u32(2) }
		else { return none }
	}
	mut first := i + 2
	if first < cs.len && cs[first] == `_` {
		first++
	}
	if first < cs.len && is_radix_digit(cs[first], radix) {
		return radix
	}

	return none
}

fn is_radix_digit(c rune, radix u32) bool {
	return match radix {
		16 { is_hexit(c) }
		8 { c >= `0` && c <= `7` }
		else { c == `0` || c == `1` }
	}
}

// read_non_decimal_integer reads the digits of an integer after its radix
// indicator (see non_decimal_radix), with the underscores, and returns them
// and the position after them. Each underscore must be followed by a digit.
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Format
fn read_non_decimal_integer(cs []rune, start int, radix u32) !(string, int) {
	mut i := start + 2
	for i < cs.len {
		if is_radix_digit(cs[i], radix) {
			i++
		} else if cs[i] == `_` && i + 1 < cs.len && is_radix_digit(cs[i + 1], radix) {
			i += 2
		} else {
			break
		}
	}

	// A digit or letter straight after it isn't another token (such as "0b12"
	// or "0xFG").
	if i < cs.len && is_identifier_char(cs[i], true) && !is_exponent(cs, i) {
		return sqlstate_42601('invalid ${radix_name(radix)} integer: ${cs[start..i + 1].string()}')
	}

	return cs[start + 2..i].string(), i
}

fn radix_name(radix u32) string {
	return match radix {
		16 { 'hexadecimal' }
		8 { 'octal' }
		else { 'binary' }
	}
}

// non_decimal_integer_value is the decimal digits of the value of the digits of
// a hexadecimal, octal or binary integer, without its underscores.
//
// ISO/IEC 9075-2:2023, 5.3, <literal>, Syntax Rules, 23 to 25
// ISO/IEC 9075-2:2023, 5.3, <literal>, General Rules, 4 to 6
fn non_decimal_integer_value(digits string, radix u32) !string {
	value := big.integer_from_radix(digits.replace('_', '').to_lower(), radix) or {
		return sqlstate_42601('invalid ${radix_name(radix)} integer: ${digits}')
	}

	return value.str()
}

fn is_hexit(c rune) bool {
	return (c >= `0` && c <= `9`) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}

fn hexit_value(c rune) int {
	return match true {
		c >= `a` { int(c - `a`) + 10 }
		c >= `A` { int(c - `A`) + 10 }
		else { int(c - `0`) }
	}
}

// is_exponent returns true if cs[i] is the E of an approximate numeric literal
// that's immediately followed by the exponent.
fn is_exponent(cs []rune, i int) bool {
	return i + 1 < cs.len && (cs[i] == `e` || cs[i] == `E`)
		&& ((cs[i + 1] >= `0` && cs[i + 1] <= `9`) || cs[i + 1] == `+` || cs[i + 1] == `-`)
}

// is_identifier_char is true if c can be in a <regular identifier>. It's only
// ASCII, rather than the Unicode letters and digits (ISO/IEC 9075-2:2023,
// 5.2, <token> and <separator>, Syntax Rules, 1 and 2), which is #761.
@[inline]
fn is_identifier_char(c rune, is_not_first bool) bool {
	yes := (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`

	if is_not_first {
		return yes || (c >= `0` && c <= `9`)
	}

	return yes
}

fn tail_substitution(tokens []Token) (int, int) {
	len := tokens.len

	if len > 2 && tokens[len - 2].token == token_operator_period
		&& tokens[len - 1].token == token_operator_asterisk {
		return 2, token_operator_period_asterisk
	}
	if len > 2 && tokens[len - 2].token == token_operator_left_paren
		&& tokens[len - 1].token == token_operator_asterisk {
		return 2, token_operator_left_paren_asterisk
	}
	if len > 2 && tokens[len - 2].token == token_is && tokens[len - 1].token == token_true {
		return 2, token_is_true
	}
	if len > 2 && tokens[len - 2].token == token_is && tokens[len - 1].token == token_false {
		return 2, token_is_false
	}
	if len > 2 && tokens[len - 2].token == token_is && tokens[len - 1].token == token_unknown {
		return 2, token_is_unknown
	}
	if len > 3 && tokens[len - 3].token == token_is && tokens[len - 2].token == token_not
		&& tokens[len - 1].token == token_true {
		return 3, token_is_not_true
	}
	if len > 3 && tokens[len - 3].token == token_is && tokens[len - 2].token == token_not
		&& tokens[len - 1].token == token_false {
		return 3, token_is_not_false
	}
	if len > 3 && tokens[len - 3].token == token_is && tokens[len - 2].token == token_not
		&& tokens[len - 1].token == token_unknown {
		return 3, token_is_not_unknown
	}

	return 0, 0
}

// reserved_words are the key words of the grammar that can't be used as a
// regular identifier, such as SELECT and FROM, sorted by name. Non-reserved
// key words, such as NAME, can be used as an identifier so they aren't
// included.
pub fn reserved_words() []string {
	// The non-reserved words come from the grammar so that they are always the
	// same as the parser.
	grammar := $embed_file('std_2_5_2_token_and_separator.y').to_string()
	mut non_reserved := map[string]bool{}
	for line in grammar.all_after('\nnon_reserved_word:\n').all_before('\n\n').split_into_lines() {
		non_reserved[line.trim_left('| ').trim_space()] = true
	}

	mut words := []string{}
	for name in yy_toknames {
		// Only words are tokens in the lexer (operators and literals are not).
		// E is a regular identifier, unless it's directly after a number, and
		// LIMIT unless it's directly before a row count.
		if name.len > 0 && name[0].is_letter() && name == name.to_upper()
			&& !name.starts_with('OPERATOR_') && !name.starts_with('LITERAL_') && name != 'E'
			&& name != 'LIMIT' && name !in non_reserved {
			words << name
		}
	}
	words.sort()

	return words
}

// extension_keywords are the key words of vsql extensions that can still be used
// as a regular identifier, so they aren't in reserved_words, sorted by name. They
// are for display, such as highlighting SQL, and mustn't decide if a name needs
// quotes.
pub fn extension_keywords() []string {
	return ['IF', 'ILIKE', 'INDEX', 'LIMIT']
}

// multi_operator_token returns the token of an operator with two characters, or
// 0 if a and b aren't one.
fn multi_operator_token(a rune, b rune) int {
	if a == `<` && b == `>` {
		return token_operator_not_equals
	}
	if a == `!` && b == `=` {
		return token_operator_bang_equals
	}
	if a == `>` && b == `=` {
		return token_operator_greater_equals
	}
	if a == `<` && b == `=` {
		return token_operator_less_equals
	}
	if a == `|` && b == `|` {
		return token_operator_double_pipe
	}
	if a == `:` && b == `:` {
		return token_operator_double_colon
	}

	return 0
}

// single_operator_token is the token of an operator that's one character, or 0
// if c isn't one. It's a match rather than a map, since it's looked up for the
// first character of every word.
fn single_operator_token(c rune) int {
	return match c {
		`(` { token_operator_left_paren }
		`)` { token_operator_right_paren }
		`*` { token_operator_asterisk }
		`+` { token_operator_plus }
		`,` { token_operator_comma }
		`-` { token_operator_minus }
		`/` { token_operator_solidus }
		`;` { token_operator_semicolon }
		`<` { token_operator_less_than }
		`=` { token_operator_equals }
		`>` { token_operator_greater_than }
		`.` { token_operator_period }
		`:` { token_operator_colon }
		else { 0 }
	}
}

// keyword_tokens is the token of each name that the grammar has.
const keyword_tokens = new_keyword_tokens()

fn new_keyword_tokens() map[string]int {
	mut tokens := map[string]int{}
	for tok_pos, tok_name in yy_toknames {
		// The name of an operator or a literal isn't a word.
		if !tok_name.starts_with('OPERATOR_') && !tok_name.starts_with('LITERAL_') {
			tokens[tok_name] = tok_pos + 57343
		}
	}

	return tokens
}
