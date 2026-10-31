module vsql

// ISO/IEC 9075-2:2016(E), 21.4, <embedded SQL C program>
//
// The <host variable definition>s in a declare section of an embedded SQL C
// program. Only the <C numeric variable>s, <C character variable>s (char) and
// <C VARCHAR variable>s are supported.

// CHostVariable is a host variable. typ is its <host parameter data type>. A
// string is a char array, and anything else is passed by its address.
struct CHostVariable {
	typ      string
	is_array bool
}

// c_declare_section reads the <C variable definition>s of a declare section,
// and returns the C to replace it with (SR 5.c, VARCHAR is char).
fn c_declare_section(text string, mut variables map[string]CHostVariable) !string {
	for definition in remove_c_comments(text).split(';') {
		if definition.trim_space() != '' {
			c_variable_definition(definition, mut variables)!
		}
	}

	// - SR 7. VARCHAR can be in any case.
	mut c := ''
	mut i := 0
	cs := text.runes()
	for i < cs.len {
		if i + 7 <= cs.len && cs[i..i + 7].string().to_upper() == 'VARCHAR'
			&& (i == 0 || !is_identifier_char(cs[i - 1], true))
			&& (i + 7 == cs.len || !is_identifier_char(cs[i + 7], true)) {
			c += 'char'
			i += 7
		} else {
			c += cs[i].str()
			i++
		}
	}

	return c
}

// c_variable_definition reads a <C variable definition> (without the
// semicolon).
fn c_variable_definition(definition string, mut variables map[string]CHostVariable) ! {
	mut words := definition.fields()
	for words.len > 0 && words[0] in ['auto', 'extern', 'static', 'const', 'volatile'] {
		words.delete(0)
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

	// - SR 4. The <host parameter data type> of each type.
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
		if name in variables {
			return sqlstate_42601('host variable ${name} is defined more than once')
		}

		// - SR 4.b.iii, iv. A string has a terminating null character, so the
		// length is one less than the array.
		if is_array != name_and_length.contains('[') || (is_array && length.int() < 2) {
			return sqlstate_42601('host variable ${name} must be ${if is_array {
				'an array of at least 2 characters'
			} else {
				'a number, not an array'
			}}')
		}
		if name == 'SQLSTATE' && !(c_type == 'char' && length.int() == 6) {
			return sqlstate_42601('SQLSTATE must be char SQLSTATE[6]')
		}

		variables[name] = CHostVariable{
			typ:      if is_array { '${sql_type}(${length.int() - 1})' } else { sql_type }
			is_array: is_array
		}
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
