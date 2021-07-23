// lexer.v contains the lexer (tokenizer) that convert a SQL string into tokens
// to be read by the parser.v

module vsql

enum TokenKind {
	eof // End of file
	keyword_character // CHARACTER
	keyword_create // CREATE
	keyword_delete // DELETE
	keyword_drop // DROP
	keyword_float // FLOAT
	keyword_from // FROM
	keyword_insert // INSERT
	keyword_into // INTO
	keyword_select // SELECT
	keyword_set // SET
	keyword_table // TABLE
	keyword_update // UPDATE
	keyword_values // VALUES
	keyword_varying // VARYING
	keyword_where // WHERE
	literal_identifier // foo
	literal_number // 123
	literal_string // 'hello'
	op_paren_open // (
	op_paren_close // )
	op_multiply // *
	op_eq // =
	op_neq // !=
	op_gt // >
	op_lt // <
	op_gte // >=
	op_lte // <=
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
		for i < cs.len && ((cs[i] >= `a` && cs[i] <= `z`) || (cs[i] >= `A` && cs[i] <= `Z`)) {
			word += '${cs[i]}'
			i++
		}

		if word == '' {
			i++
			continue
		}

		tokens << match word.to_upper() {
			'CHARACTER' { Token{TokenKind.keyword_character, word} }
			'CREATE' { Token{TokenKind.keyword_create, word} }
			'DELETE' { Token{TokenKind.keyword_delete, word} }
			'DROP' { Token{TokenKind.keyword_drop, word} }
			'FLOAT' { Token{TokenKind.keyword_float, word} }
			'FROM' { Token{TokenKind.keyword_from, word} }
			'INSERT' { Token{TokenKind.keyword_insert, word} }
			'INTO' { Token{TokenKind.keyword_into, word} }
			'SELECT' { Token{TokenKind.keyword_select, word} }
			'SET' { Token{TokenKind.keyword_set, word} }
			'TABLE' { Token{TokenKind.keyword_table, word} }
			'UPDATE' { Token{TokenKind.keyword_update, word} }
			'VALUES' { Token{TokenKind.keyword_values, word} }
			'VARYING' { Token{TokenKind.keyword_varying, word} }
			'WHERE' { Token{TokenKind.keyword_where, word} }
			else { Token{TokenKind.literal_identifier, word} }
		}
	}

	tokens << Token{TokenKind.eof, ''}

	return tokens
}
