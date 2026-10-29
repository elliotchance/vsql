module vsql

// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>
//
// An <embedded SQL C program> (see 21.4) is C with "EXEC SQL ...;" statements.
// "vsql precompile" turns it into the implied program (Syntax Rule 23), C that
// calls the procedures of the implied <SQL-client module definition> (Syntax
// Rule 22), which is compiled into the same file (see 13.1).
//
// This is a simple precompiler. It finds each EXEC SQL that isn't in a C
// comment or string, and the semicolon that ends it, without parsing the C.

// PrecompiledProgram is the C of an <embedded SQL C program>, and its implied
// module.
pub struct PrecompiledProgram {
pub:
	implied_module string
	source         string
}

// precompile_c precompiles an <embedded SQL C program>. file_name is used for
// the #line of the C, so that the C compiler reports the lines of the program.
pub fn precompile_c(source string, file_name string) !PrecompiledProgram {
	// Git may check out the program with CRLF line endings (on Windows).
	cs := source.replace('\r\n', '\n').runes()
	mut program := ''
	mut implied := 'MODULE LANGUAGE C SCHEMA "PUBLIC"\n'
	mut variables := map[string]CHostVariable{}
	mut cursors := map[string][]string{}
	mut whenever := EmbeddedExceptionDeclarations{}
	mut in_declare := false
	mut procedure_lines := []int{}
	mut start := 0
	mut i := 0
	for i < cs.len {
		if i + 1 < cs.len && cs[i] == `/` && cs[i + 1] == `/` {
			for i < cs.len && cs[i] != `\n` {
				i++
			}
			continue
		}
		if i + 1 < cs.len && cs[i] == `/` && cs[i + 1] == `*` {
			i += 2
			for i + 1 < cs.len && !(cs[i] == `*` && cs[i + 1] == `/`) {
				i++
			}
			i += 2
			continue
		}
		if cs[i] == `"` || cs[i] == `'` {
			quote := cs[i]
			i++
			for i < cs.len && cs[i] != quote && cs[i] != `\n` {
				i += if cs[i] == `\\` { 2 } else { 1 }
			}
			i++
			continue
		}
		after := exec_sql_end(cs, i)
		if after < 0 {
			i++
			continue
		}

		// - SR 3.c. The statement ends with a semicolon.
		line := cs[..i].count(it == `\n`) + 1
		mut end := after
		for end < cs.len && cs[end] != `;` {
			if is_comment(cs, end) {
				end = skip_comment(cs, end) or { return embedded_error(line, err) }
			} else if cs[end] == `'` {
				_, end, _ = read_string_literal(cs, end) or { return embedded_error(line, err) }
			} else if cs[end] == `"` {
				end = skip_delimited_identifier(cs, end)
			} else {
				end++
			}
		}
		if end >= cs.len {
			return embedded_error(line, sqlstate_42601('EXEC SQL must end with a semicolon'))
		}

		if in_declare {
			program += c_declare_section(cs[start..i].string(), mut variables) or {
				return embedded_error(line, err)
			}
		} else {
			program += cs[start..i].string()
		}
		text := cs[after..end].string()
		new_lines := '\n'.repeat(cs[i..end].count(it == `\n`))
		start = end + 1
		i = end + 1

		mut t := new_module_tokens(text) or { return embedded_error(line, err) }
		first := t.next_word()
		if first == 'BEGIN' || first == 'END' {
			if t.accept('DECLARE') && t.accept('SECTION') && t.peek() == none {
				if in_declare == (first == 'BEGIN') {
					return embedded_error(line, sqlstate_42601('unexpected ${first} DECLARE SECTION'))
				}
				in_declare = first == 'BEGIN'
				program += new_lines
				continue
			}
		}
		if in_declare {
			return embedded_error(line, sqlstate_42601('a declare section can only contain host variable definitions'))
		}

		// - SR 19, 20. SQLSTATE is defined before any <embedded SQL statement>.
		if 'SQLSTATE' !in variables {
			return embedded_error(line, sqlstate_42601('SQLSTATE must be defined in a declare section before the first EXEC SQL'))
		}

		mut names := embedded_variable_names(text) or { return embedded_error(line, err) }
		match first {
			'WHENEVER' {
				whenever.declare(mut t) or { return embedded_error(line, err) }
				program += new_lines
				continue
			}
			'DECLARE' {
				if t.accept('SCHEMA') || t.accept('AUTHORIZATION') {
					return embedded_error(line, sqlstate_42601('DECLARE SCHEMA and DECLARE AUTHORIZATION are not supported'))
				}
				for name in names {
					variables[name] or {
						return embedded_error(line, sqlstate_42601('host variable :${name} is not defined'))
					}
				}

				// - SR 22.h. The cursor is copied to the module, and it's
				// opened with the host variables in it.
				cursor := declare_module_cursor(text, 0) or { return embedded_error(line, err) }
				cursors[cursor.name] = names
				implied += text.trim_space() + ';\n'
				program += new_lines
				continue
			}
			'OPEN' {
				// - SR 15. A cursor is declared before it's opened.
				name := t.identifier('a cursor name') or { return embedded_error(line, err) }
				cursor_names := cursors[name] or {
					return embedded_error(line, sqlstate_42601('cursor ${name} must be declared before it is opened'))
				}
				for n in cursor_names.reverse() {
					if n !in names {
						names.prepend(n)
					}
				}
			}
			else {}
		}

		// - SR 22.l. A procedure for the <SQL procedure statement>, with each
		// host variable in it.
		procedure := 'vsql_e${procedure_lines.len + 1}'
		procedure_lines << line
		mut parameters := ['SQLSTATE']
		mut args := ['SQLSTATE']
		for name in names {
			variable := variables[name] or {
				return embedded_error(line, sqlstate_42601('host variable :${name} is not defined'))
			}
			parameters << ':${name} ${variable.typ}'
			args << if variable.is_array { name } else { '&${name}' }
		}
		implied += 'PROCEDURE ${procedure} (${parameters.join(', ')});\n  ${text.trim_space()};\n'

		// - SR 23.d. The statement is replaced by a call of its procedure, and
		// the exception actions (see 21.2).
		program += '{ ${procedure}(${args.join(', ')});${whenever.c_checks()} }${new_lines}'
	}

	if in_declare {
		return embedded_error(cs.count(it == `\n`) + 1, sqlstate_42601('END DECLARE SECTION is missing'))
	}
	if procedure_lines.len == 0 {
		return sqlstate_42601('an embedded SQL program must have an SQL statement')
	}
	program += cs[start..].string()

	// An error in a procedure of the module is reported at its line.
	m := parse_sql_client_module(implied) or {
		mut message := err.msg()
		for j := procedure_lines.len - 1; j >= 0; j-- {
			message = message.replace('procedure vsql_e${j + 1}:', 'line ${procedure_lines[j]}:')
		}
		return error_with_code(message, err.code())
	}

	return PrecompiledProgram{
		implied_module: implied
		source:         m.c_source('', true) + '#line 1 ${c_string(file_name)}\n' + program
	}
}

// exec_sql_end returns the position after the "EXEC SQL" (the <SQL prefix>)
// at cs[i], or -1 if there isn't one. SR 5. Its words are separated by spaces.
fn exec_sql_end(cs []rune, i int) int {
	if (i > 0 && is_identifier_char(cs[i - 1], true)) || i + 4 > cs.len
		|| cs[i..i + 4].string().to_upper() != 'EXEC' {
		return -1
	}
	mut j := i + 4
	for j < cs.len && cs[j] == ` ` {
		j++
	}
	if j == i + 4 || j + 3 > cs.len || cs[j..j + 3].string().to_upper() != 'SQL'
		|| (j + 3 < cs.len && is_identifier_char(cs[j + 3], true)) {
		return -1
	}

	return j + 3
}

// embedded_variable_names returns each distinct <embedded variable name> in
// the text of a statement, in order, without the colon.
fn embedded_variable_names(text string) ![]string {
	cs := text.runes()
	mut names := []string{}
	mut i := 0
	for i < cs.len {
		if is_comment(cs, i) {
			i = skip_comment(cs, i)!
		} else if cs[i] == `'` {
			_, i, _ = read_string_literal(cs, i)!
		} else if cs[i] == `"` {
			i = skip_delimited_identifier(cs, i)
		} else if cs[i] == `:` {
			i++
			start := i
			for i < cs.len && is_identifier_char(cs[i], i > start) {
				i++
			}
			name := cs[start..i].string()
			if name != '' && name !in names {
				names << name
			}
		} else {
			i++
		}
	}

	return names
}

// embedded_error is an error at a line of the program.
fn embedded_error(line int, err IError) IError {
	return error_with_code(err.msg().replace_once('syntax error: ', 'syntax error: line ${line}: '),
		err.code())
}
