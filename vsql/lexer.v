// lexer.v contains the lexer (tokenizer) that convert a SQL string into tokens
// to be read by the parser.v

module vsql

// YYSym allows for every possible type that needs to pass through $$ rules in
// the grammar. If V ever supports some kind of "any" type this would be a
// little easier.
type YYSym = AddColumnDefinition
	| AddTableConstraintDefinition
	| AggregateFunction
	| AggregateFunctionCount
	| AlterColumnAction
	| AlterColumnDefinition
	| AlterIdentityColumnSpecification
	| AlterSequenceGeneratorStatement
	| AlterTableAction
	| BetweenPredicate
	| BooleanPredicand
	| BooleanPrimary
	| BooleanTerm
	| BooleanTest
	| BooleanValueExpression
	| CaseExpression
	| CaseExpressionSearched
	| CaseExpressionSearchedWhen
	| CaseExpressionSimple
	| CaseExpressionSimpleWhen
	| CaseResult
	| CastOperand
	| CastSpecification
	| CharacterLikePredicate
	| CharacterLikePredicatePart2
	| CharacterPrimary
	| CharacterSubstringFunction
	| CharacterValueExpression
	| CharacterValueFunction
	| CheckConstraintDefinition
	| Column
	| ColumnConstraint
	| CommonValueExpression
	| ComparisonPredicate
	| ComparisonOperator
	| ComparisonPredicatePart2
	| Concatenation
	| ContextuallyTypedRowValueConstructor
	| ContextuallyTypedRowValueConstructorElement
	| ContextuallyTypedValueSpecification
	| Correlation
	| CurrentDate
	| CurrentTime
	| CurrentTimestamp
	| DatetimePrimary
	| DatetimeValueFunction
	| DefaultOption
	| DefaultSpecification
	| DerivedColumn
	| DropColumnDefaultClause
	| DropColumnDefinition
	| DropTableConstraintDefinition
	| ExistsPredicate
	| ExplicitRowValueConstructor
	| GeneralValueSpecification
	| GenerationClause
	| Identifier
	| IdentityColumn
	| IdentifierChain
	| InPredicate
	| InsertStatement
	| JoinType
	| LocalTime
	| LocalTimestamp
	| NextValueExpression
	| NonparenthesizedValueExpressionPrimary
	| NullPredicate
	| NullSpecification
	| NumericPrimary
	| NumericValueExpression
	| ParenthesizedValueExpression
	| Predicate
	| QualifiedAsteriskExpr
	| QuantifiedComparisonPredicate
	| QualifiedJoin
	| QueryExpression
	| QuerySpecification
	| ReferentialConstraintDefinition
	| RoutineInvocation
	| RowValueConstructor
	| RowValueConstructorPredicand
	| SelectList
	| SelectSublist
	| SequenceGeneratorDefinition
	| SequenceGeneratorIncrementByOption
	| SequenceGeneratorMaxvalueOption
	| SequenceGeneratorMinvalueOption
	| SequenceGeneratorOption
	| SequenceGeneratorRestartOption
	| SequenceGeneratorStartWithOption
	| SetClause
	| SetColumnDefaultClause
	| SetSchemaStatement
	| SimilarPredicate
	| SimilarPredicatePart2
	| SimpleTable
	| SortSpecification
	| Subquery
	| Stmt
	| Table
	| TableElement
	| TableExpression
	| TablePrimary
	| TableReference
	| Term
	| TrimFunction
	| Type
	| UniqueConstraintDefinition
	| UpdateSource
	| Value
	| ValueExpression
	| ValueExpressionPrimary
	| ValueSpecification
	| []CaseExpressionSearchedWhen
	| []CaseExpressionSimpleWhen
	| []ContextuallyTypedRowValueConstructor
	| []ContextuallyTypedRowValueConstructorElement
	| []DerivedColumn
	| []Identifier
	| []RowValueConstructor
	| []RowValueConstructorPredicand
	| []SelectSublist
	| []SequenceGeneratorOption
	| []SetClause
	| []SortSpecification
	| []TableElement
	| []ValueExpression
	| bool
	| string

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

struct YYSymType {
mut:
	v   YYSym
	yys int
}

struct Lexer {
mut:
	tokens []Token
	pos    int
}

fn (mut l Lexer) lex(mut lval YYSymType) int {
	if l.pos >= l.tokens.len {
		return 0
	}

	l.pos++
	unsafe {
		*lval = l.tokens[l.pos - 1].sym
	}
	return l.tokens[l.pos - 1].token
}

fn (mut l Lexer) error(s string) IError {
	return sqlstate_42601(cleanup_yacc_error(s))
}

fn cleanup_yacc_error(s string) string {
	mut msg := s

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
	msg = msg.replace('OPERATOR_COLON', '":"')
	msg = msg.replace('OPERATOR_LESS_THAN', '"<"')
	msg = msg.replace('OPERATOR_GREATER_THAN', '">"')
	msg = msg.replace('OPERATOR_NOT_EQUALS', '"<>"')
	msg = msg.replace('OPERATOR_GREATER_EQUALS', '">="')
	msg = msg.replace('OPERATOR_LESS_EQUALS', '"<="')
	msg = msg.replace('OPERATOR_PERIOD_ASTERISK', '"." "*"')
	msg = msg.replace('OPERATOR_LEFT_PAREN_ASTERISK', '"(" "*"')

	msg = msg.replace('LITERAL_IDENTIFIER', 'identifier')
	msg = msg.replace('LITERAL_STRING', 'string')
	msg = msg.replace('LITERAL_NUMBER', 'number')

	return msg['syntax error: '.len..]
}

struct Token {
	token int
	sym   YYSymType
}

fn tokenize(sql_stmt string) ![]Token {
	mut tokens := []Token{}
	cs := sql_stmt.trim(';').runes()
	mut i := 0

	for i < cs.len {
		// A comment is a separator, the same as a space.
		if is_comment(cs, i) {
			i = skip_comment(cs, i)
			continue
		}

		// Numbers
		if cs[i] >= `0` && cs[i] <= `9` {
			mut word := ''
			for i < cs.len && cs[i] >= `0` && cs[i] <= `9` {
				word += '${cs[i]}'
				i++
			}
			tokens << Token{token_literal_number, YYSymType{
				v: word
			}}

			// There is a special case for approximate numbers where 'E' is considered
			// a separate token in the SQL BNF. However, "e2" should not be treated as
			// two tokens, but rather we need to catch this case only when with a
			// number token. The literal is a single token (5.2 Syntax Rule 5), so the
			// exponent must follow the E without any spaces. A mantissa may also end
			// with a period, such as "1.e5".
			if is_exponent(cs, i + 1) && cs[i] == `.` {
				tokens << Token{token_operator_period, YYSymType{
					v: '.'
				}}
				i++
			}
			if is_exponent(cs, i) {
				tokens << Token{token_e, YYSymType{}}
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
			mut word, end := read_string_literal(cs, i)!
			i = end
			if is_unicode {
				escape, escape_end := read_unicode_escape_specifier(cs, i)!
				i = escape_end
				word = unescape_unicode(word, escape)!
			}
			tokens << Token{token_literal_string, YYSymType{
				v: new_character_value(word)
			}}
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
			tokens << Token{token_literal_identifier, YYSymType{
				v: IdentifierChain{
					identifier: '"${word}"'
				}
			}}
			unsafe {
				goto next
			}
		}

		// Operators
		multi := {
			'<>': token_operator_not_equals
			'>=': token_operator_greater_equals
			'<=': token_operator_less_equals
			'||': token_operator_double_pipe
		}
		for op, tk in multi {
			if i < cs.len - 1 && cs[i] == op[0] && cs[i + 1] == op[1] {
				tokens << Token{tk, YYSymType{
					v: op
				}}
				i += 2
				unsafe {
					goto next
				}
			}
		}

		single := {
			`(`: token_operator_left_paren
			`)`: token_operator_right_paren
			`*`: token_operator_asterisk
			`+`: token_operator_plus
			`,`: token_operator_comma
			`-`: token_operator_minus
			`/`: token_operator_solidus
			`;`: token_operator_semicolon
			`<`: token_operator_less_than
			`=`: token_operator_equals
			`>`: token_operator_greater_than
			`.`: token_operator_period
			`:`: token_operator_colon
		}
		for op, tk in single {
			if cs[i] == op {
				tokens << Token{tk, YYSymType{
					v: op.str()
				}}
				i++
				unsafe {
					goto next
				}
			}
		}

		// Keyword or regular identifier
		mut word := ''
		mut is_not_first := false
		for i < cs.len && is_identifier_char(cs[i], is_not_first) {
			word += '${cs[i]}'
			i++
			is_not_first = true
		}

		if word == '' {
			i++
			continue
		}

		upper_word := word.to_upper()
		mut found := false
		for tok_pos, tok_name in yy_toknames {
			// E is only a token directly after a number (see above), otherwise it's
			// a regular identifier.
			if tok_name == upper_word && upper_word != 'E' {
				tok_number := tok_pos + 57343
				tokens << Token{tok_number, YYSymType{
					v: upper_word
				}}
				found = true
				break
			}
		}

		if !found {
			tokens << Token{token_literal_identifier, YYSymType{
				v: IdentifierChain{
					identifier: word
				}
			}}
		}

		next:
		length, new_token := tail_substitution(tokens)
		if length > 0 {
			tokens = tokens[..tokens.len - length].clone()
			tokens << Token{new_token, YYSymType{}}
		}
	}

	return tokens
}

// read_string_literal returns the characters of the string that starts with
// the quote at cs[i], and the position after it. A doubled quote ('') is a
// single quote. Strings that are only separated by spaces that include a new
// line are one string, so 'ab' is the same as:
//
//   'a'
//   'b'
//
// A string without a closing quote is a syntax error.
//
// ISO/IEC 9075-2:2016(E), 5.3, <literal>, Syntax Rules 1, 2 and 7
fn read_string_literal(cs []rune, start int) !(string, int) {
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
	for j < cs.len {
		if is_comment(cs, j) {
			j = skip_comment(cs, j)
		} else if cs[j].str().trim_space() == '' {
			has_newline = has_newline || cs[j] == `\n`
			j++
		} else {
			break
		}
	}
	if has_newline && j < cs.len && cs[j] == `'` {
		next_word, end := read_string_literal(cs, j)!
		return word + next_word, end
	}

	return word, i
}

// is_comment returns true if a simple comment starts at cs[i]. A simple comment
// starts with two (or more) minus signs and continues to the end of the line.
//
// ISO/IEC 9075-2:2016(E), 5.2, <token> and <separator>
fn is_comment(cs []rune, i int) bool {
	return i + 1 < cs.len && cs[i] == `-` && cs[i + 1] == `-`
}

// skip_comment returns the position of the new line that ends the comment that
// starts at cs[i], or the end of the SQL if there isn't one.
fn skip_comment(cs []rune, start int) int {
	mut i := start
	for i < cs.len && cs[i] != `\n` {
		i++
	}
	return i
}

// read_unicode_escape_specifier returns the escape character of a Unicode
// string, from the optional UESCAPE '<character>' after the string at cs[i],
// and the position after it. Otherwise, the escape character is a backslash.
//
// ISO/IEC 9075-2:2016(E), 5.2, <token> and <separator>, Syntax Rules 16 to 18
fn read_unicode_escape_specifier(cs []rune, start int) !(rune, int) {
	mut i := start
	for i < cs.len && cs[i].str().trim_space() == '' {
		i++
	}
	if i + 7 > cs.len || cs[i..i + 7].string().to_upper() != 'UESCAPE'
		|| (i + 7 < cs.len && is_identifier_char(cs[i + 7], true)) {
		return `\\`, start
	}

	i += 7
	for i < cs.len && cs[i].str().trim_space() == '' {
		i++
	}
	if i + 2 >= cs.len || cs[i] != `'` || cs[i + 2] != `'` {
		return sqlstate_42601('UESCAPE must be followed by a single character in quotes')
	}

	escape := cs[i + 1]
	if is_hexit(escape) || escape in [`+`, `'`, `"`] || escape.str().trim_space() == '' {
		return sqlstate_42601("invalid Unicode escape character: '${escape}'")
	}

	return escape, i + 3
}

// unescape_unicode replaces each escape in a Unicode string: the escape
// character followed by 4 hexits (such as \0041 for A), a plus and 6 hexits
// (such as \+01F600), or another escape character (for the escape character
// itself).
//
// ISO/IEC 9075-2:2016(E), 5.2, <token> and <separator>, Syntax Rules 19 to 23
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
