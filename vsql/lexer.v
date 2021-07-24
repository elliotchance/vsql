// lexer.v contains the lexer (tokenizer) that convert a SQL string into tokens
// to be read by the parser.v

module vsql

enum TokenKind {
	eof // End of file
	keyword_bigint // BIGINT
	keyword_boolean // BOOLEAN
	keyword_char // CHAR
	keyword_character // CHARACTER
	keyword_create // CREATE
	keyword_delete // DELETE
	keyword_double // DOUBLE
	keyword_drop // DROP
	keyword_false // FALSE
	keyword_float // FLOAT
	keyword_from // FROM
	keyword_insert // INSERT
	keyword_int // INT
	keyword_integer // INTEGER
	keyword_into // INTO
	keyword_precision // PRECISION
	keyword_real // REAL
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
	literal_identifier // foo or "foo" (delimited)
	literal_number // 123
	literal_string // 'hello'
	op_comma // ,
	op_eq // =
	op_gt // >
	op_gte // >=
	op_lt // <
	op_lte // <=
	op_multiply // *
	op_neq // !=
	op_paren_close // )
	op_paren_open // (
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
			tokens << Token{TokenKind.literal_number, word}
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
			tokens << Token{TokenKind.literal_string, word}
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
			tokens << Token{TokenKind.literal_identifier, '"$word"'}
			continue
		}

		// operators
		multi := map{
			'!=': TokenKind.op_neq
			'>=': TokenKind.op_gte
			'<=': TokenKind.op_lte
		}
		for op, tk in multi {
			if cs[i] == op[0] && cs[i + 1] == op[1] {
				tokens << Token{tk, op}
				i += 2
				continue next
			}
		}

		single := map{
			`(`: TokenKind.op_paren_open
			`)`: TokenKind.op_paren_close
			`=`: TokenKind.op_eq
			`>`: TokenKind.op_gt
			`<`: TokenKind.op_lt
			`*`: TokenKind.op_multiply
			`,`: TokenKind.op_comma
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
			'BIGINT' { Token{TokenKind.keyword_bigint, word} }
			'BOOLEAN' { Token{TokenKind.keyword_boolean, word} }
			'CHAR' { Token{TokenKind.keyword_char, word} }
			'CHARACTER' { Token{TokenKind.keyword_character, word} }
			'CREATE' { Token{TokenKind.keyword_create, word} }
			'DELETE' { Token{TokenKind.keyword_delete, word} }
			'DOUBLE' { Token{TokenKind.keyword_double, word} }
			'DROP' { Token{TokenKind.keyword_drop, word} }
			'FALSE' { Token{TokenKind.keyword_false, word} }
			'FLOAT' { Token{TokenKind.keyword_float, word} }
			'FROM' { Token{TokenKind.keyword_from, word} }
			'INSERT' { Token{TokenKind.keyword_insert, word} }
			'INT' { Token{TokenKind.keyword_int, word} }
			'INTEGER' { Token{TokenKind.keyword_integer, word} }
			'INTO' { Token{TokenKind.keyword_into, word} }
			'PRECISION' { Token{TokenKind.keyword_precision, word} }
			'REAL' { Token{TokenKind.keyword_real, word} }
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
