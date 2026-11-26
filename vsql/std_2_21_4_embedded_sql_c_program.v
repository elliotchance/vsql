module vsql

// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>
//
// The <host variable definition>s in a declare section of an embedded SQL C
// program. Only the <C numeric variable>s, <C character variable>s (char), <C
// VARCHAR variable>s and <C CLOB variable>s (without a CHARACTER SET), <C
// BINARY variable>s, <C VARBINARY variable>s and <C BLOB variable>s are
// supported. There are no locators (T041).
//
// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 1 to 3

// CHostVariable is a host variable. typ is its <host parameter data type>, and
// arg is the C argument that passes it to a procedure of the implied module: a
// string is a char array, a BINARY is an unsigned char array (passed as a char
// array), and anything else is passed by its address.
struct CHostVariable {
	typ string
	arg string
}

// c_declare_section reads the <C variable definition>s of a declare section,
// and returns the C to replace it with, where VARCHAR is char. The length of a
// char array (other than SQLSTATE, which is always char SQLSTATE[6]) is
// multiplied by k, the maximum octets in a UTF-8 character.
//
// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 5.a, 5.c and 5.d
fn c_declare_section(text string, mut variables map[string]CHostVariable) !string {
	for definition in remove_c_comments(text).split(';') {
		if definition.trim_space() != '' {
			c_variable_definition(definition, mut variables)!
		}
	}

	// The length is the first brackets of a declarator, which isn't in a
	// <C initial value>. It's checked by c_variable_definition.
	mut c := ''
	mut i := 0
	mut word := ''
	mut depth := 0
	mut initial := false
	cs := text.runes()
	for i < cs.len {
		mut j := i + 1
		if is_identifier_char(cs[i], false) {
			for j < cs.len && is_identifier_char(cs[j], true) {
				j++
			}
			word = cs[i..j].string()

			// A <C BINARY variable>, <C VARBINARY variable>, <C CLOB variable>
			// or <C BLOB variable> is replaced up to its semicolon, keeping its
			// lines.
			if word.to_upper() == 'SQL' && depth == 0 && !initial {
				end := c_definition_end(cs, i)
				definition := cs[i..end].string()
				c += c_binary_definition(remove_c_comments(definition))! +
					'\n'.repeat(definition.count('\n'))
				i = end
				continue
			}

			// VARCHAR can be in any case.
			//
			// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 7
			c += if word.to_upper() == 'VARCHAR' { 'char' } else { word }
		} else if cs[i] == `[` && depth == 0 && !initial && word != 'SQLSTATE' {
			j = i + cs[i..].index(`]`) + 1
			c += '[${cs[i + 1..j - 1].string().trim_space().int() * max_utf8_octets}]'
		} else {
			j = skip_c_token(cs, i)
			match cs[i] {
				`(`, `[`, `{` { depth++ }
				`)`, `]`, `}` { depth-- }
				`=` { initial = initial || depth == 0 }
				`,`, `;` { initial = initial && depth > 0 }
				else {}
			}
			c += cs[i..j].string()
		}
		i = j
	}

	return c
}

// c_definition_end is the position of the semicolon that ends the <C variable
// definition> at cs[i] (or the end of cs).
fn c_definition_end(cs []rune, i int) int {
	mut j := i
	for j < cs.len && cs[j] != `;` {
		j = skip_c_token(cs, j)
	}

	return j
}

// c_binary_definition is the C that replaces a <C BINARY variable>, a <C
// VARBINARY variable>, a <C CLOB variable> or a <C BLOB variable> (without the
// semicolon). Each <C host identifier> has its own struct for a VARBINARY,
// CLOB or BLOB. The data portion of a CLOB(L) has L*k octets.
//
// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 5.f, 5.g, 5.h and 5.i
fn c_binary_definition(definition string) !string {
	typ, length, declarators := c_binary_type(definition)!
	octets := if typ == 'CLOB' { length * max_utf8_octets } else { length }
	mut c := []string{}
	for declarator in declarators {
		name := declarator.all_before('=').trim_space()
		initial := if declarator.contains('=') { ' =${declarator.all_after('=')}' } else { '' }
		c << if typ == 'BINARY' {
			'${name}[${length}]${initial}'
		} else {
			'struct { long ${name}_reserved; unsigned long ${name}_length; char ${name}_data[${octets}]; } ${name}${initial}'
		}
	}

	return if typ == 'BINARY' { 'unsigned char ${c.join(', ')}' } else { c.join('; ') }
}

// c_binary_type reads the type (BINARY, VARBINARY, CLOB or BLOB), the length
// and the declarators of a <C BINARY variable>, <C VARBINARY variable>, <C CLOB
// variable> or <C BLOB variable>, which is "SQL TYPE IS BINARY ( L )" (and so
// on) followed by one or more <C host identifier>s, each with an optional <C
// initial value>. The length of a CLOB or BLOB is a number, without K, M or G.
//
// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 4.c.i and 4.c.ii
fn c_binary_type(definition string) !(string, int, []string) {
	words := definition.replace('(', ' ( ').replace(')', ' ) ').fields()
	if words.len < 8 || words[..3].map(it.to_upper()) != ['SQL', 'TYPE', 'IS']
		|| words[3].to_upper() !in ['BINARY', 'VARBINARY', 'CLOB', 'BLOB'] || words[4] != '(' || words[6] != ')'
		|| words[5].int() < 1 || words[5].int().str() != words[5] {
		return sqlstate_42601('unsupported host variable definition: ${definition.trim_space()}')
	}
	rest := definition.all_after(')')
	declarators := split_c_declarators(rest)
	for declarator in declarators {
		name := declarator.all_before('=').trim_space()
		if name == '' || !name.runes().all(is_identifier_char(it, true))
			|| !is_identifier_char(name.runes()[0], false) {
			return sqlstate_42601('unsupported host variable definition: ${definition.trim_space()}')
		}
	}

	return words[3].to_upper(), words[5].int(), declarators
}

// skip_c_token returns the position after the C comment, string literal or
// character constant that starts at cs[i], or after cs[i] if it doesn't start
// one.
fn skip_c_token(cs []rune, i int) int {
	mut j := i + 1
	if cs[i] == `/` && j < cs.len && cs[j] == `/` {
		for j < cs.len && cs[j] != `\n` {
			j++
		}
		return j
	}
	if cs[i] == `/` && j < cs.len && cs[j] == `*` {
		j += 2
		for j < cs.len && !(cs[j - 1] == `*` && cs[j] == `/`) {
			j++
		}
	} else if cs[i] == `"` || cs[i] == `'` {
		for j < cs.len && cs[j] != cs[i] {
			j += if cs[j] == `\\` { 2 } else { 1 }
		}
	} else {
		return j
	}

	return if j < cs.len { j + 1 } else { cs.len }
}

// c_variable_definition reads a <C variable definition> (without the
// semicolon). A <C initial value> is any C after the "=", which the C compiler
// checks.
//
// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 6
fn c_variable_definition(definition string, mut variables map[string]CHostVariable) ! {
	mut words := definition.fields()
	for words.len > 0 && words[0] in ['auto', 'extern', 'static', 'const', 'volatile'] {
		words.delete(0)
	}

	// The <host parameter data type> of a BINARY, VARBINARY, CLOB or BLOB.
	// It's a host parameter of the implied module, which needs T021, T046 or
	// T045 (see parameter_features).
	//
	// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 4.b.i, 4.b.v, 4.c.i, 4.c.ii and 4.c.iii
	// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Conformance Rules, 7, 8, 12 and 13
	if words.len > 0 && words[0].to_upper() == 'SQL' {
		typ, length, declarators := c_binary_type(words.join(' '))!
		for declarator in declarators {
			name := declarator.all_before('=').trim_space()
			check_new_c_host_variable(variables, name)!
			variables[name] = CHostVariable{
				typ: match typ {
					'BINARY' { 'BINARY(${length})' }
					'VARBINARY' { 'BINARY VARYING(${length})' }
					'CLOB' { 'CHARACTER LARGE OBJECT(${length})' }
					else { 'BINARY LARGE OBJECT(${length})' }
				}
				arg: if typ == 'BINARY' { '(char *)${name}' } else { '&${name}' }
			}
		}
		return
	}
	mut c_type := if words.len > 0 { words[0] } else { '' }
	mut type_words := 1
	if c_type == 'long' && words.len > 1 && words[1] == 'long' {
		c_type = 'long long'
		type_words = 2
	}
	if c_type.to_upper() == 'VARCHAR' {
		c_type = 'VARCHAR'
	}

	// The <host parameter data type> of each type.
	//
	// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 4.a.i to 4.a.v
	// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 4.b.i
	sql_type := match c_type {
		'long long' { 'BIGINT' }
		'long' { 'INTEGER' }
		'short' { 'SMALLINT' }
		'float' { 'REAL' }
		'double' { 'DOUBLE PRECISION' }
		'char' { 'CHARACTER' }
		'VARCHAR' { 'CHARACTER VARYING' }
		else {
			return sqlstate_42601('unsupported host variable definition: ${definition.trim_space()}')
		}
	}
	is_array := c_type in ['char', 'VARCHAR']
	declarators := words[type_words..].join(' ')

	for declarator in split_c_declarators(declarators) {
		name_and_length := declarator.all_before('=').trim_space()
		name := name_and_length.all_before('[').trim_space()
		length := name_and_length.all_after('[').all_before(']').trim_space()
		if name == '' || !name.runes().all(is_identifier_char(it, true))
			|| !is_identifier_char(name.runes()[0], false) {
			return sqlstate_42601('unsupported host variable definition: ${definition.trim_space()}')
		}
		check_new_c_host_variable(variables, name)!

		// A string has a terminating null character, so the length is one less
		// than the array.
		//
		// ISO/IEC 9075-2:2023, 21.4, <embedded SQL C program>, Syntax Rules, 4.b.iii and 4.b.iv
		if is_array != name_and_length.contains('[') || (is_array && length.int() < 2) {
			return sqlstate_42601('host variable ${name} must be ${if is_array {
				'an array of at least 2 characters'
			} else {
				'a number, not an array'
			}}')
		}
		// ISO/IEC 9075-2:2023, 13.3, <externally-invoked procedure>, Syntax Rules, 11.a
		if name == 'SQLSTATE' && !(c_type == 'char' && length.int() == 6) {
			return sqlstate_42601('SQLSTATE must be char SQLSTATE[6]')
		}

		variables[name] = CHostVariable{
			typ: if is_array { '${sql_type}(${length.int() - 1})' } else { sql_type }
			arg: if is_array { name } else { '&${name}' }
		}
	}
}

// check_new_c_host_variable returns an error if a host variable called name is
// already defined.
//
// ISO/IEC 9075-2:2023, 21.1, <embedded SQL host program>, Syntax Rules, 16
fn check_new_c_host_variable(variables map[string]CHostVariable, name string) ! {
	if name in variables {
		return sqlstate_42601('host variable ${name} is defined more than once')
	}
}

// split_c_declarators splits the declarators of a definition at each comma
// that isn't in brackets, braces, parentheses or a string.
fn split_c_declarators(text string) []string {
	mut parts := []string{}
	mut depth := 0
	mut quote := rune(0)
	mut start := 0
	cs := text.runes()
	for i, c in cs {
		if quote != 0 {
			if c == quote && cs[i - 1] != `\\` {
				quote = 0
			}
		} else if c == `"` || c == `'` {
			quote = c
		} else if c in [`(`, `[`, `{`] {
			depth++
		} else if c in [`)`, `]`, `}`] {
			depth--
		} else if c == `,` && depth == 0 {
			parts << cs[start..i].string()
			start = i + 1
		}
	}
	parts << cs[start..].string()

	return parts
}

// remove_c_comments replaces each C comment with a space.
fn remove_c_comments(text string) string {
	mut s := ''
	mut i := 0
	cs := text.runes()
	for i < cs.len {
		if i + 1 < cs.len && cs[i] == `/` && cs[i + 1] == `/` {
			for i < cs.len && cs[i] != `\n` {
				i++
			}
			s += ' '
		} else if i + 1 < cs.len && cs[i] == `/` && cs[i + 1] == `*` {
			i += 2
			for i + 1 < cs.len && !(cs[i] == `*` && cs[i + 1] == `/`) {
				i++
			}
			i += 2
			s += ' '
		} else {
			s += cs[i].str()
			i++
		}
	}

	return s
}
