// lexer.v contains the lexer (tokenizer) that convert a SQL string into tokens
// to be read by the parser.v

module vsql

type YYSym = Value | ValueSpecification | ValueExpression | RowValueConstructor
  | []RowValueConstructor | BooleanValueExpression | NumericValueExpression
  | CommonValueExpression | BooleanTerm | ValueExpressionPrimary | SelectList
  | NumericPrimary | Term | BooleanTest | BooleanPrimary | BooleanPredicand
  | NonparenthesizedValueExpressionPrimary | SimpleTable | QueryExpression
  | Stmt | string | Identifier | IdentifierChain | RoutineInvocation
  | []ContextuallyTypedRowValueConstructor | NextValueExpression | DerivedColumn
  | ContextuallyTypedRowValueConstructor | CaseExpression | TableExpression
  | []vsql.ValueExpression | []SequenceGeneratorOption | QualifiedAsteriskExpr
  | AlterSequenceGeneratorStatement | SequenceGeneratorOption | []DerivedColumn
  | SequenceGeneratorRestartOption | CastSpecification | CharacterPrimary
  | SortSpecification | []SortSpecification | bool | TablePrimary
  | map[string]UpdateSource | UpdateSource | NullSpecification | []TableElement
  | TableElement | DatetimePrimary | DatetimeValueFunction | CastOperand | Type
  | GeneralValueSpecification | []Identifier | InsertStatement | Concatenation
  | ParenthesizedValueExpression | AggregateFunction | CharacterValueFunction
  | CharacterSubstringFunction | TrimFunction | CharacterValueExpression
  | BetweenPredicate | RowValueConstructorPredicand | CharacterLikePredicate
  | ComparisonPredicatePart2 | ComparisonPredicate | QuerySpecification
  | ExplicitRowValueConstructor | ContextuallyTypedRowValueConstructorElement
  | []ContextuallyTypedRowValueConstructorElement | TableReference
  | QualifiedJoin | Correlation | SequenceGeneratorDefinition
  | SequenceGeneratorStartWithOption | SequenceGeneratorIncrementByOption
  | SequenceGeneratorMaxvalueOption | SequenceGeneratorMinvalueOption
  | Predicate | UniqueConstraintDefinition | CurrentDate
  | CurrentTime | LocalTime | CurrentTimestamp | LocalTimestamp | NullPredicate
  | SimilarPredicate | Column | SetSchemaStatement | AggregateFunctionCount
  | Table;

struct YYSymType {
mut:
  v YYSym
  yys int
}

struct Lexer {
mut:
  tokens []Tok
  pos int
}

fn (mut l Lexer) lex(mut lval YYSymType) int {
  if l.pos >= l.tokens.len {
    return 0
  }

  l.pos++
  unsafe { *lval = l.tokens[l.pos-1].sym }
  return l.tokens[l.pos-1].token
}

fn (mut l Lexer) error(s string)! {
  return sqlstate_42601(cleanup_yacc_error(s))
}

fn cleanup_yacc_error(s string) string {
	mut msg := s
	msg = msg.replace("OPERATOR_COMMA", '","')
	msg = msg.replace("OPERATOR_RIGHT_PAREN", '")"')
	msg = msg.replace("OPERATOR_DOUBLE_PIPE", '"||"')
	msg = msg.replace("OPERATOR_PLUS", '"+"')
	msg = msg.replace("OPERATOR_MINUS", '"-"')
	msg = msg.replace("OPERATOR_SEMICOLON", '";"')
	msg = msg.replace("OPERATOR_EQUALS", '"="')
	msg = msg.replace("OPERATOR_LEFT_PAREN", '"("')
	msg = msg.replace("OPERATOR_ASTERISK", '"*"')
	msg = msg.replace("OPERATOR_PERIOD", '"."')
	msg = msg.replace("OPERATOR_SOLIDUS", '"/"')
	msg = msg.replace("OPERATOR_COLON", '":"')
	msg = msg.replace("OPERATOR_LESS_THAN", '"<"')
	msg = msg.replace("OPERATOR_GREATER_THAN", '">"')
	msg = msg.replace("OPERATOR_NOT_EQUALS", '"<>"')
	msg = msg.replace("OPERATOR_GREATER_EQUALS", '">="')
	msg = msg.replace("OPERATOR_LESS_EQUALS", '"<="')
	msg = msg.replace("OPERATOR_PERIOD_ASTERISK", '"." "*"')
	msg = msg.replace("OPERATOR_LEFT_PAREN_ASTERISK", '"(" "*"')

	return msg['syntax error: '.len..]
}

// Except for the eof and the keywords, the other tokens use the names described
// in the SQL standard.
enum TokenKind {
	asterisk                        // <asterisk> ::= *
	colon                           // <colon> ::= :
	comma                           // <comma> ::= ,
	concatenation_operator          // <concatenation operator> ::= ||
	equals_operator                 // <equals operator> ::= =
	greater_than_operator           // <greater than operator> ::= >
	greater_than_or_equals_operator // <greater than or equals operator> ::= >=
	keyword
	left_paren                   // <left paren> ::= (
	less_than_operator           // <less than operator> ::= <
	less_than_or_equals_operator // <less than or equals operator> ::= <=
	literal_identifier           // foo or "foo" (delimited)
	literal_number               // 123
	literal_string               // 'hello'
	minus_sign                   // <minus sign> ::= -
	not_equals_operator          // <not equals operator> ::= <>
	period                       // <period> ::= .
	plus_sign                    // <plus sign> ::= +
	right_paren                  // <right paren> ::= )
	semicolon                    // <semicolon> ::= ;
	solidus                      // <solidus> ::= /
}

struct Token {
pub:
	kind  TokenKind
	value string
}

fn tokenize(sql_stmt string) []Token {
	mut tokens := []Token{}
	cs := sql_stmt.trim(';').runes()
	mut i := 0

	next: for i < cs.len {
		// Numbers
		if cs[i] >= `0` && cs[i] <= `9` {
			mut word := ''
			for i < cs.len && cs[i] >= `0` && cs[i] <= `9` {
				word += '${cs[i]}'
				i++
			}
			tokens << Token{.literal_number, word}

			// There is a special case for approximate numbers where 'E' is considered
			// a separate token in the SQL BNF. However, "e2" should not be treated as
			// two tokens, but rather we need to catch this case only when with a
			// number token.
			if i < cs.len && (cs[i] == `e` || cs[i] == `E`) {
				tokens << Token{.keyword, 'E'}
				i++
			}

			continue
		}

		// Strings
		if cs[i] == `'` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `'` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Token{.literal_string, word}
			continue
		}

		// Delimited identifiers
		if cs[i] == `"` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `"` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Token{.literal_identifier, '"${word}"'}
			continue
		}

		// Operators
		multi := {
			'<>': TokenKind.not_equals_operator
			'>=': TokenKind.greater_than_or_equals_operator
			'<=': TokenKind.less_than_or_equals_operator
			'||': TokenKind.concatenation_operator
		}
		for op, tk in multi {
			if cs[i] == op[0] && cs[i + 1] == op[1] {
				tokens << Token{tk, op}
				i += 2
				continue next
			}
		}

		single := {
			`(`: TokenKind.left_paren
			`)`: TokenKind.right_paren
			`*`: TokenKind.asterisk
			`+`: TokenKind.plus_sign
			`,`: TokenKind.comma
			`-`: TokenKind.minus_sign
			`/`: TokenKind.solidus
			`;`: TokenKind.semicolon
			`<`: TokenKind.less_than_operator
			`=`: TokenKind.equals_operator
			`>`: TokenKind.greater_than_operator
			`.`: TokenKind.period
			`:`: TokenKind.colon
		}
		for op, tk in single {
			if cs[i] == op {
				tokens << Token{tk, op.str()}
				i++
				continue next
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

		tokens << if is_key_word(word) {
			Token{TokenKind.keyword, word.to_upper()}
		} else {
			Token{TokenKind.literal_identifier, word}
		}
	}

	return tokens
}

@[inline]
fn is_identifier_char(c rune, is_not_first bool) bool {
	yes := (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`

	if is_not_first {
		return yes || (c >= `0` && c <= `9`)
	}

	return yes
}

pub struct Tok {
pub:
  token int
  sym YYSymType
}

fn tokenize2(sql_stmt string) []Tok {
	mut tokens := []Tok{}
	cs := sql_stmt.trim(';').runes()
	mut i := 0

	next: for i < cs.len {
		// Numbers
		if cs[i] >= `0` && cs[i] <= `9` {
			mut word := ''
			for i < cs.len && cs[i] >= `0` && cs[i] <= `9` {
				word += '${cs[i]}'
				i++
			}
			tokens << Tok{token_literal_number, YYSymType{v: word}}

			// There is a special case for approximate numbers where 'E' is considered
			// a separate token in the SQL BNF. However, "e2" should not be treated as
			// two tokens, but rather we need to catch this case only when with a
			// number token.
			if i < cs.len && (cs[i] == `e` || cs[i] == `E`) {
				tokens << Tok{token_e, YYSymType{}}
				i++
			}

			continue
		}

		// Strings
		if cs[i] == `'` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `'` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Tok{token_literal_string, YYSymType{v: new_character_value(word)}}
			continue
		}

		// Delimited identifiers
		if cs[i] == `"` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `"` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Tok{token_literal_identifier, YYSymType{v: IdentifierChain{identifier: '"${word}"'}}}
			continue
		}

		// Operators
		multi := {
			'<>': token_operator_not_equals
			'>=': token_operator_greater_equals
			'<=': token_operator_less_equals
			'||': token_operator_double_pipe
			// fake
			'.*': token_operator_period_asterisk
			'(*': token_operator_left_paren_asterisk
		}
		for op, tk in multi {
			if i < cs.len - 1 && cs[i] == op[0] && cs[i + 1] == op[1] {
				tokens << Tok{tk, YYSymType{v: op}}
				i += 2
				continue next
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
				tokens << Tok{tk, YYSymType{v: op.str()}}
				i++
				continue next
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
			if tok_name == upper_word {
				tok_number := tok_pos + 57343
				tokens << Tok{tok_number, YYSymType{v: upper_word}}

				length, new_token := tail_substitution(tokens)
				if length > 0 {
					tokens = tokens[..tokens.len-length].clone()
					tokens << Tok{new_token, YYSymType{}}
				}

				// TODO: explain this
				len := tokens.len
				if len > 2 && tokens[len-2].token == token_is && tokens[len-1].token == token_true {
					tokens = tokens[..tokens.len-2].clone()
					tokens << Tok{token_is_true, YYSymType{}}
				}
				if len > 2 && tokens[len-2].token == token_is && tokens[len-1].token == token_false {
					tokens = tokens[..tokens.len-2].clone()
					tokens << Tok{token_is_false, YYSymType{}}
				}
				if len > 2 && tokens[len-2].token == token_is && tokens[len-1].token == token_unknown {
					tokens = tokens[..tokens.len-2].clone()
					tokens << Tok{token_is_unknown, YYSymType{}}
				}
				if len > 3 && tokens[len-3].token == token_is && tokens[len-2].token == token_not && tokens[len-1].token == token_true {
					tokens = tokens[..tokens.len-3].clone()
					tokens << Tok{token_is_not_true, YYSymType{}}
				}
				if len > 3 && tokens[len-3].token == token_is && tokens[len-2].token == token_not && tokens[len-1].token == token_false {
					tokens = tokens[..tokens.len-3].clone()
					tokens << Tok{token_is_not_false, YYSymType{}}
				}
				if len > 3 && tokens[len-3].token == token_is && tokens[len-2].token == token_not && tokens[len-1].token == token_unknown {
					tokens = tokens[..tokens.len-3].clone()
					tokens << Tok{token_is_not_unknown, YYSymType{}}
				}

				found = true
				break
			}
		}
		
		if !found {
			tokens << Tok{token_literal_identifier, YYSymType{v: IdentifierChain{identifier: word}}}
		}
	}

	return tokens
}

fn tail_substitution(tokens []Tok) (int, int) {
	len := tokens.len

	if len > 2 && tokens[len-2].token == token_is && tokens[len-1].token == token_true {
		return 2, token_is_true
	}
	if len > 2 && tokens[len-2].token == token_is && tokens[len-1].token == token_false {
		return 2, token_is_false
	}
	if len > 2 && tokens[len-2].token == token_is && tokens[len-1].token == token_unknown {
		return 2, token_is_unknown
	}
	if len > 3 && tokens[len-3].token == token_is && tokens[len-2].token == token_not && tokens[len-1].token == token_true {
		return 3, token_is_not_true
	}
	if len > 3 && tokens[len-3].token == token_is && tokens[len-2].token == token_not && tokens[len-1].token == token_false {
		return 3, token_is_not_false
	}
	if len > 3 && tokens[len-3].token == token_is && tokens[len-2].token == token_not && tokens[len-1].token == token_unknown {
		return 3, token_is_not_unknown
	}

	return 0, 0
}
