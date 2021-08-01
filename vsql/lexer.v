// lexer.v contains the lexer (tokenizer) that convert a SQL string into tokens
// to be read by the parser.v

module vsql

// Except for the eof and the keywords, the other tokens use the names described
// in the SQL standard.
enum TokenKind {
	eof // End of file
	asterisk // <asterisk> ::= *
	comma // <comma> ::= ,
	concatenation_operator // <concatenation operator> ::= ||
	equals_operator // <equals operator> ::= =
	greater_than_operator // <greater than operator> ::= >
	greater_than_or_equals_operator // <greater than or equals operator> ::= >=
	keyword_and // AND
	keyword_as // AS
	keyword_bigint // BIGINT
	keyword_boolean // BOOLEAN
	keyword_char // CHAR
	keyword_character // CHARACTER
	keyword_create // CREATE
	keyword_delete // DELETE
	keyword_double // DOUBLE
	keyword_drop // DROP
	keyword_false // FALSE
	keyword_fetch // FETCH
	keyword_first // FIRST
	keyword_float // FLOAT
	keyword_from // FROM
	keyword_insert // INSERT
	keyword_int // INT
	keyword_integer // INTEGER
	keyword_into // INTO
	keyword_is // IS
	keyword_not // NOT
	keyword_null // NULL
	keyword_offset // OFFSET
	keyword_only // ONLY
	keyword_or // OR
	keyword_precision // PRECISION
	keyword_real // REAL
	keyword_row // ROW
	keyword_rows // ROWS
	keyword_select // SELECT
	keyword_set // SET
	keyword_smallint // SMALLINT
	keyword_table // TABLE
	keyword_true // TRUE
	keyword_unknown // UNKNOWN
	keyword_update // UPDATE
	keyword_values // VALUES
	keyword_varchar // VARCHAR
	keyword_varying // VARYING
	keyword_where // WHERE
	left_paren // <left paren> ::= (
	less_than_operator // <less than operator> ::= <
	less_than_or_equals_operator // <less than or equals operator> ::= <=
	literal_identifier // foo or "foo" (delimited)
	literal_number // 123
	literal_string // 'hello'
	minus_sign // <minus sign> ::= -
	not_equals_operator // <not equals operator> ::= <>
	plus_sign // <plus sign> ::= +
	right_paren // <right paren> ::= )
	semicolon // <semicolon> ::= ;
	solidus // <solidus> ::= /
}

struct Token {
pub:
	kind  TokenKind
	value string
}

fn tokenize(sql string) []Token {
	mut tokens := []Token{}
	cs := sql.runes()
	mut i := 0

	next: for i < cs.len {
		// space
		if cs[i] == ` ` {
			i++
			continue
		}

		// numbers
		if cs[i] >= `0` && cs[i] <= `9` {
			mut word := ''
			for i < cs.len && ((cs[i] >= `0` && cs[i] <= `9`) || cs[i] == `.`) {
				word += '${cs[i]}'
				i++
			}
			tokens << Token{.literal_number, word}
			continue
		}

		// strings
		if cs[i] == `\'` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `\'` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Token{.literal_string, word}
			continue
		}

		// delimited identifiers
		if cs[i] == `"` {
			mut word := ''
			i++
			for i < cs.len && cs[i] != `"` {
				word += '${cs[i]}'
				i++
			}
			i++
			tokens << Token{.literal_identifier, '"$word"'}
			continue
		}

		// operators
		multi := map{
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

		single := map{
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
		}
		for op, tk in single {
			if cs[i] == op {
				tokens << Token{tk, op.str()}
				i++
				continue next
			}
		}

		// keyword or identifier
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

		tokens << match word.to_upper() {
			'AND' { Token{TokenKind.keyword_and, word} }
			'AS' { Token{TokenKind.keyword_as, word} }
			'BIGINT' { Token{TokenKind.keyword_bigint, word} }
			'BOOLEAN' { Token{TokenKind.keyword_boolean, word} }
			'CHAR' { Token{TokenKind.keyword_char, word} }
			'CHARACTER' { Token{TokenKind.keyword_character, word} }
			'CREATE' { Token{TokenKind.keyword_create, word} }
			'DELETE' { Token{TokenKind.keyword_delete, word} }
			'DOUBLE' { Token{TokenKind.keyword_double, word} }
			'DROP' { Token{TokenKind.keyword_drop, word} }
			'FALSE' { Token{TokenKind.keyword_false, word} }
			'FETCH' { Token{TokenKind.keyword_fetch, word} }
			'FIRST' { Token{TokenKind.keyword_first, word} }
			'FLOAT' { Token{TokenKind.keyword_float, word} }
			'FROM' { Token{TokenKind.keyword_from, word} }
			'INSERT' { Token{TokenKind.keyword_insert, word} }
			'INT' { Token{TokenKind.keyword_int, word} }
			'INTEGER' { Token{TokenKind.keyword_integer, word} }
			'INTO' { Token{TokenKind.keyword_into, word} }
			'IS' { Token{TokenKind.keyword_is, word} }
			'NOT' { Token{TokenKind.keyword_not, word} }
			'NULL' { Token{TokenKind.keyword_null, word} }
			'OFFSET' { Token{TokenKind.keyword_offset, word} }
			'ONLY' { Token{TokenKind.keyword_only, word} }
			'OR' { Token{TokenKind.keyword_or, word} }
			'PRECISION' { Token{TokenKind.keyword_precision, word} }
			'REAL' { Token{TokenKind.keyword_real, word} }
			'ROW' { Token{TokenKind.keyword_row, word} }
			'ROWS' { Token{TokenKind.keyword_rows, word} }
			'SELECT' { Token{TokenKind.keyword_select, word} }
			'SET' { Token{TokenKind.keyword_set, word} }
			'SMALLINT' { Token{TokenKind.keyword_smallint, word} }
			'TABLE' { Token{TokenKind.keyword_table, word} }
			'TRUE' { Token{TokenKind.keyword_true, word} }
			'UNKNOWN' { Token{TokenKind.keyword_unknown, word} }
			'UPDATE' { Token{TokenKind.keyword_update, word} }
			'VALUES' { Token{TokenKind.keyword_values, word} }
			'VARCHAR' { Token{TokenKind.keyword_varchar, word} }
			'VARYING' { Token{TokenKind.keyword_varying, word} }
			'WHERE' { Token{TokenKind.keyword_where, word} }
			else { Token{TokenKind.literal_identifier, word} }
		}
	}

	tokens << Token{TokenKind.eof, ''}

	return tokens
}

[inline]
fn is_identifier_char(c byte, is_not_first bool) bool {
	yes := (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`

	if is_not_first {
		return yes || (c >= `0` && c <= `9`)
	}

	return yes
}

fn precedence(tk TokenKind) int {
	return match tk {
		.asterisk, .solidus {
			2
		}
		.plus_sign, .minus_sign {
			3
		}
		.equals_operator, .not_equals_operator, .less_than_operator, .less_than_or_equals_operator,
		.greater_than_operator, .greater_than_or_equals_operator {
			4
		}
		.keyword_and {
			6
		}
		.keyword_or {
			7
		}
		else {
			panic(tk)
			0
		}
	}
}
