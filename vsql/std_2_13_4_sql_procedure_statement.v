module vsql

// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>
//
// Define all of the SQL-statements that are <SQL procedure statement>s.

// ModuleStatement is the <SQL procedure statement> of a procedure, compiled to
// the body of its C function.
struct ModuleStatement {
	// sections are the parts of the C runtime that c uses.
	sections []string
	// parameters are the (upper case) names of the host parameters that c
	// uses.
	parameters []string
	c          string
}

// HostParameterReference is a <host parameter specification> in a statement.
// The indicator is empty when there's no <indicator parameter>.
struct HostParameterReference {
	name      string
	indicator string
}

// parse_module_statement compiles the statement of a procedure. A connection
// statement is done by the C runtime. Any other statement is checked here (so
// that a syntax error is found when the module is compiled) and then prepared
// and executed with libvsql, with a "?" for each host parameter. START
// TRANSACTION, COMMIT and ROLLBACK can only be done with SQLStartTran and
// SQLEndTran.
fn parse_module_statement(text string, p ExternallyInvokedProcedure) !ModuleStatement {
	tokens := tokenize(text) or { return procedure_error(p, err) }

	// A <dynamic parameter specification> can only be in a prepared statement.
	if tokens.any(it.token == token_operator_question_mark) {
		return sqlstate_42601('procedure ${p.name}: a module cannot contain a dynamic parameter (?), use a host parameter (:name)')
	}

	mut t := new_module_tokens(text)!
	match t.next_word() {
		'CONNECT' {
			return t.connect_statement(p)
		}
		'DISCONNECT' {
			return t.disconnect_statement(p)
		}
		'SET' {
			if t.accept('CONNECTION') {
				return t.set_connection_statement(p)
			}
		}
		else {}
	}

	text_sql, references := rewrite_host_parameters(text, p)!
	stmt := parse_tokens(tokenize(text_sql)!) or { return procedure_error(p, err) }

	return match stmt {
		QueryExpression {
			sqlstate_42601('procedure ${p.name}: a query is not an SQL procedure statement')
		}
		StartTransactionStatement {
			ModuleStatement{['connection', 'start'], [], '  vsql_m_start(SQLSTATE);\n'}
		}
		CommitStatement {
			ModuleStatement{['connection', 'end'], [], '  vsql_m_end(SQLSTATE, SQL_COMMIT);\n'}
		}
		RollbackStatement {
			ModuleStatement{['connection', 'end'], [], '  vsql_m_end(SQLSTATE, SQL_ROLLBACK);\n'}
		}
		else {
			execute_statement(text_sql, references, p)!
		}
	}
}

fn procedure_error(p ExternallyInvokedProcedure, err IError) IError {
	return sqlstate_42601('procedure ${p.name}: ${err.msg().all_after('syntax error: ')}')
}

// execute_statement binds each host parameter to its "?" (in the
// struct vsql_m_param array) and executes the statement.
fn execute_statement(text_sql string, references []HostParameterReference, p ExternallyInvokedProcedure) !ModuleStatement {
	mut sections := ['connection', 'execute']
	mut used := []string{}
	mut params := []string{}
	mut checks := ''
	for i, reference in references {
		// - 13.3 SR 3. Each host parameter must be declared.
		parameter := p.reference(reference.name)!
		typ := parameter.typ or { HostParameterType{} }
		params << '    ${typ.c_parameter(parameter.name)}'
		used << parameter.name.to_upper()

		mut check := ''
		if typ.is_string() {
			check = 'if (!vsql_m_string(SQLSTATE, ${parameter.name}, ${typ.length + 1})) {\n    return;\n  }\n'
			if 'string' !in sections {
				sections << 'string'
			}
		}

		// - 6.4 SR 5. An <indicator parameter> is an exact numeric, and a
		// negative value is NULL.
		if reference.indicator != '' {
			indicator := p.reference(reference.indicator)!
			indicator_type := indicator.typ or { HostParameterType{} }
			if !indicator_type.is_exact_numeric() {
				return sqlstate_42601('procedure ${p.name}: indicator parameter :${indicator.name} must be SMALLINT, INTEGER or BIGINT')
			}
			used << indicator.name.to_upper()
			checks += '  if (*${indicator.name} < 0) {\n    vsql_m_p[${i}].indicator = SQL_NULL_DATA;\n  }'
			checks += if check == '' { '\n' } else { ' else ${check}' }
		} else if check != '' {
			checks += '  ${check}'
		}
	}

	if params.len == 0 {
		return ModuleStatement{sections, used, '  vsql_m_execute(SQLSTATE, ${c_string(text_sql.trim_space())}, 0, NULL);\n'}
	}

	mut c := '  struct vsql_m_param vsql_m_p[${params.len}] = {\n${params.join(',\n')}};\n'
	c += checks
	c += '  vsql_m_execute(SQLSTATE, ${c_string(text_sql.trim_space())}, ${params.len}, vsql_m_p);\n'

	return ModuleStatement{sections, used, c}
}

// reference is the host parameter for a <host parameter name> in the
// statement, which must be declared (13.3 Syntax Rule 3).
fn (p ExternallyInvokedProcedure) reference(name string) !HostParameterDeclaration {
	return p.parameter(name) or {
		return sqlstate_42601('procedure ${p.name}: host parameter :${name} is not declared')
	}
}

// rewrite_host_parameters replaces each <host parameter specification> (a
// host parameter name, and an optional indicator parameter) with a "?" that
// has the declared type of the host parameter, and each comment with a space.
fn rewrite_host_parameters(text string, p ExternallyInvokedProcedure) !(string, []HostParameterReference) {
	cs := text.runes()
	mut text_sql := ''
	mut references := []HostParameterReference{}
	mut i := 0
	for i < cs.len {
		if is_comment(cs, i) {
			i = skip_comment(cs, i)!
			text_sql += ' '
		} else if cs[i] == `'` {
			_, end, _ := read_string_literal(cs, i)!
			text_sql += cs[i..end].string()
			i = end
		} else if cs[i] == `"` {
			end := int_min(skip_delimited_identifier(cs, i), cs.len)
			text_sql += cs[i..end].string()
			i = end
		} else if cs[i] == `:` {
			name, end := read_host_parameter_name(cs, i)!
			i = end

			// <indicator parameter> ::= [ INDICATOR ] <host parameter name>
			mut indicator := ''
			mut j := skip_spaces(cs, i)
			if j + 9 < cs.len && cs[j..j + 9].string().to_upper() == 'INDICATOR'
				&& !is_identifier_char(cs[j + 9], true) {
				j = skip_spaces(cs, j + 9)
				if j >= cs.len || cs[j] != `:` {
					return sqlstate_42601('expected an indicator parameter after INDICATOR')
				}
			}
			if j < cs.len && cs[j] == `:` {
				indicator, i = read_host_parameter_name(cs, j)!
			}

			references << HostParameterReference{name, indicator}
			typ := p.reference(name)!.typ or { HostParameterType{} }
			text_sql += 'CAST(? AS ${typ.sql()})'
		} else {
			text_sql += cs[i].str()
			i++
		}
	}

	return text_sql, references
}

// read_host_parameter_name reads ":name" at cs[i], and returns the name and
// the position after it.
fn read_host_parameter_name(cs []rune, i int) !(string, int) {
	mut j := i + 1
	for j < cs.len && is_identifier_char(cs[j], j > i + 1) {
		j++
	}
	if j == i + 1 {
		return sqlstate_42601('expected a host parameter name after :')
	}

	return cs[i + 1..j].string(), j
}

fn skip_spaces(cs []rune, i int) int {
	mut j := i
	for j < cs.len && cs[j].str().trim_space() == '' {
		j++
	}

	return j
}

// ConnectionArguments are the host parameters that a connection statement
// uses.
struct ConnectionArguments {
mut:
	sections   []string
	parameters []string
	checks     string
}

// connect_statement compiles a <connect statement> (18.1), after CONNECT.
fn (mut t ModuleTokens) connect_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	t.expect('TO')!
	mut a := ConnectionArguments{
		sections: ['name', 'switch', 'connect']
	}
	mut args := ['NULL', 'NULL', 'NULL']
	if !t.accept('DEFAULT') {
		args[0] = t.connection_value(p, mut a)!
		if t.accept('AS') {
			args[1] = t.connection_value(p, mut a)!
		}
		if t.accept('USER') {
			args[2] = t.connection_value(p, mut a)!
		}
	}

	return t.connection_statement(a, 'vsql_m_connect(SQLSTATE, ${args.join(', ')})')
}

// set_connection_statement compiles a <set connection statement> (18.2), after
// SET CONNECTION.
fn (mut t ModuleTokens) set_connection_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	mut a := ConnectionArguments{
		sections: ['name', 'switch', 'set_connection']
	}
	name := if t.accept('DEFAULT') { 'NULL' } else { t.connection_value(p, mut a)! }

	return t.connection_statement(a, 'vsql_m_set_connection(SQLSTATE, ${name})')
}

// disconnect_statement compiles a <disconnect statement> (18.3), after
// DISCONNECT.
fn (mut t ModuleTokens) disconnect_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	mut a := ConnectionArguments{
		sections: ['name', 'disconnect']
	}
	mut args := ''
	if t.accept('DEFAULT') {
		args = "'D', NULL"
	} else if t.accept('ALL') {
		args = "'A', NULL"
	} else if t.accept('CURRENT') {
		args = "'C', NULL"
	} else {
		args = "'n', ${t.connection_value(p, mut a)!}"
	}

	return t.connection_statement(a, 'vsql_m_disconnect(SQLSTATE, ${args})')
}

fn (t ModuleTokens) connection_statement(a ConnectionArguments, call string) !ModuleStatement {
	if t.pos < t.tokens.len {
		return sqlstate_42601('unexpected${t.near()}')
	}

	return ModuleStatement{a.sections, a.parameters, '${a.checks}  ${call};\n'}
}

// connection_value is the C value of a connection name, SQL-server name or
// user name. It's a <simple value specification>, which is a character string
// literal or a host parameter that is a CHARACTER or CHARACTER VARYING.
fn (mut t ModuleTokens) connection_value(p ExternallyInvokedProcedure, mut a ConnectionArguments) !string {
	if tok := t.peek() {
		if tok.kind == .literal {
			t.pos++
			return c_string(tok.text)
		}
	}

	if t.accept(':') {
		parameter := p.reference(t.c_name('host parameter name')!)!
		typ := parameter.typ or { HostParameterType{} }
		if !typ.is_string() {
			return sqlstate_42601('procedure ${p.name}: host parameter :${parameter.name} must be CHARACTER or CHARACTER VARYING')
		}
		a.parameters << parameter.name.to_upper()
		a.checks += '  if (!vsql_m_string(SQLSTATE, ${parameter.name}, ${typ.length + 1})) {\n    return;\n  }\n'
		a.sections << 'string'

		return parameter.name
	}

	return sqlstate_42601('procedure ${p.name}: expected a string or a host parameter${t.near()}')
}
