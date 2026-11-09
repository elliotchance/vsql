module vsql

// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>
//
// An <embedded SQL C program> is C with "EXEC SQL ...;" statements. "vsql
// precompile" turns it into the implied program, C that calls the procedures of
// the implied <SQL-client module definition>, which is compiled into the same
// file (see SQLClientModule.c_source).
//
// This is a simple precompiler. It finds each EXEC SQL that isn't in a C
// comment or string, and the semicolon that ends it, without parsing the C.
// Only C (Feature B012, "Embedded C") is supported.
//
// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 1 and 17.b
// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 21 to 23
// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, General Rules, 1
//
// Embedded SQL is one of the binding styles of a host language, described by
// ISO/IEC 9075-1:2003(E), 4.8.1, Host languages.
//
// The concepts are also described by:
//
// ISO/IEC 9075-2:2016(E), 4.29, Embedded syntax
// ISO/IEC 9075-2:2016(E), 4.37, Host languages
// ISO/IEC 9075-2:2016(E), 4.39.6, Embeddable SQL-statements

// PrecompiledProgram is the C of an <embedded SQL C program>, and its implied
// module.
pub struct PrecompiledProgram {
pub:
	implied_module string
	source         string
	// features are the Feature IDs outside of Core SQL that the program uses
	// (see the SQL Flagging docs), sorted and without duplicates. The implied
	// module doesn't need the language of a module (B112).
	features []string
}

// precompile_c precompiles an <embedded SQL C program>. file_name is used for
// the #line of the C, so that the C compiler reports the lines of the program.
pub fn precompile_c(source string, file_name string) !PrecompiledProgram {
	// Git may check out the program with CRLF line endings (on Windows).
	cs := source.replace('\r\n', '\n').runes()
	mut program := ''

	// The implied module has no name, and its schema is PUBLIC. It has the
	// default character set and SQL-path, since there's no <embedded character
	// set declaration> (F461) or <embedded path specification> (S071).
	//
	// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 12
	// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.a to 22.c
	// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.d.ii
	// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.e.ii
	mut implied := 'MODULE LANGUAGE C SCHEMA "PUBLIC"\n'
	mut variables := map[string]CHostVariable{}
	// The cursors declared so far, each with the C call of the procedure that
	// opens it, which is empty for a dynamic cursor.
	mut cursors := map[string]string{}
	// The procedures that open a cursor, which aren't called yet.
	mut uncalled := []string{}
	mut whenever := EmbeddedExceptionDeclarations{}
	mut runtime := []string{}
	mut in_declare := false
	mut procedure_lines := []int{}
	// ISO/IEC 9075-2:2016(E), 21.4, <embedded SQL C program>, Conformance Rules, 1
	mut features := ['B012']
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

		// The statement ends with a semicolon.
		//
		// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 3.c
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

		// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 23.b
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

		// A declare section is deleted, other than its definitions.
		//
		// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 23.a
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

		// SQLSTATE is defined before any <embedded SQL statement>.
		//
		// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 19 and 20
		if 'SQLSTATE' !in variables {
			return embedded_error(line, sqlstate_42601('SQLSTATE must be defined in a declare section before the first EXEC SQL'))
		}

		names := embedded_variable_names(text) or { return embedded_error(line, err) }
		mut call := ''
		match first {
			// The exception actions are in the implied program, instead of the
			// implied module.
			//
			// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.k
			// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 23.c
			'WHENEVER' {
				whenever.declare(mut t, 'PUBLIC') or { return embedded_error(line, err) }
				features << whenever_features(t.tokens[1].text)
				program += new_lines
				continue
			}
			'DECLARE' {
				// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Conformance Rules, 1
				if t.accept('SCHEMA') || t.accept('AUTHORIZATION') {
					return embedded_error(line, sqlstate_42601('DECLARE SCHEMA and DECLARE AUTHORIZATION are not supported'))
				}

				// The cursor (or dynamic cursor) is copied to the module, and
				// it's deleted from the program. There's one procedure that opens
				// a <declare cursor>, with the host variables in it, whether the
				// program has no OPEN of the cursor or several.
				//
				// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.h
				// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.i
				// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 23.c
				cursor := declare_module_cursor(text, 0) or { return embedded_error(line, err) }
				implied += text.trim_space() + ';\n'
				cursors[cursor.name] = ''
				if cursor.statement == '' {
					procedure, open_call := embedded_procedure(mut procedure_lines, line,
						'OPEN ${cursor.sql_name}', names, variables) or {
						return embedded_error(line, err)
					}
					implied += procedure
					cursors[cursor.name] = open_call
					uncalled << open_call.all_before('(')
				}
				program += new_lines
				continue
			}
			'OPEN' {
				// A cursor is declared before it's opened.
				//
				// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 14 and 15
				// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.l.ii
				name := t.identifier('a cursor name') or { return embedded_error(line, err) }
				call = cursors[name] or {
					return embedded_error(line, sqlstate_42601('cursor ${name} must be declared before it is opened'))
				}
				if call != '' {
					// The arguments are the host variables of the cursor, so
					// the statement can't have any.
					if t.peek() != none {
						return embedded_error(line, sqlstate_42601('unexpected${t.near()}'))
					}
					uncalled = uncalled.filter(it != call.all_before('('))
				}
			}
			else {}
		}

		// Each procedure is for one statement, other than the OPEN of a
		// <declare cursor>.
		if call == '' {
			procedure, statement_call := embedded_procedure(mut procedure_lines, line, text,
				names, variables) or { return embedded_error(line, err) }
			implied += procedure
			call = statement_call
		}

		// The statement is replaced by a call of its procedure, and the
		// exception actions.
		//
		// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 23.d
		program += '{ ${call};${whenever.c_checks()} }${new_lines}'
		if whenever.constraints.len > 0 {
			runtime = ['violated']
		}
	}

	if in_declare {
		return embedded_error(cs.count(it == `\n`) + 1, sqlstate_42601('END DECLARE SECTION is missing'))
	}
	// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 1
	if procedure_lines.len == uncalled.len {
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

	// A <C numeric variable> that contains long long, even if it's not used.
	//
	// ISO/IEC 9075-2:2016(E), 21.4, <embedded SQL C program>, Conformance Rules, 11
	if variables.values().any(it.typ == 'BIGINT') {
		features << 'T071'
	}
	features << m.features

	// A static function that isn't called would be a warning of the C compiler,
	// so it's only in the implied module.
	called := SQLClientModule{
		...m
		procedures: m.procedures.filter(it.name !in uncalled)
	}

	return PrecompiledProgram{
		implied_module: implied
		source:         called.c_source('', true, runtime) + '#line 1 ${c_string(file_name)}\n' +
			program
		features:       unique_features(features)
	}
}

// embedded_procedure returns a procedure of the implied module for an <SQL
// procedure statement>, with each host variable, which must be defined before
// it, and the C call of the procedure.
//
// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 16
// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.l.i.1 to 22.l.i.5
// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 22.l.i.9
fn embedded_procedure(mut procedure_lines []int, line int, text string, names []string, variables map[string]CHostVariable) !(string, string) {
	procedure := 'vsql_e${procedure_lines.len + 1}'
	procedure_lines << line
	mut parameters := ['SQLSTATE']
	mut args := ['SQLSTATE']
	for name in names {
		variable := variables[name] or {
			return sqlstate_42601('host variable :${name} is not defined')
		}
		parameters << ':${name} ${variable.typ}'
		args << if variable.is_array { name } else { '&${name}' }
	}

	return 'PROCEDURE ${procedure} (${parameters.join(', ')});\n  ${text.trim_space()};\n', '${procedure}(${args.join(', ')})'
}

// exec_sql_end returns the position after the "EXEC SQL" (the <SQL prefix>)
// at cs[i], or -1 if there isn't one. Its words are separated by spaces.
//
// ISO/IEC 9075-2:2016(E), 21.1, <embedded SQL host program>, Syntax Rules, 2.b and 5
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
