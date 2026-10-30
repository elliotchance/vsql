module vsql

// ISO/IEC 9075-2:2016(E), 14.7, <select statement: single row>
//
// Retrieve values from a specified row of a table.
//
// It's only in an SQL-client module, where each target is a host parameter, so
// it's compiled into C that executes the query with libvsql and gets the
// values of the row with SQLGetData.

// split_select_into splits a statement that starts with SELECT, and has an INTO
// that isn't in parentheses, into the <query specification> (without INTO and
// the <select target list>) and the <select target list>. The targets are
// empty for any other statement.
fn split_select_into(text string) !(string, string) {
	cs := text.runes()
	mut depth := 0
	mut words := 0
	mut into_start := -1
	mut into_end := -1
	mut from := cs.len
	mut i := 0
	for i < cs.len {
		if is_comment(cs, i) {
			i = skip_comment(cs, i)!
		} else if cs[i] == `'` {
			_, i, _ = read_string_literal(cs, i)!
		} else if cs[i] == `"` {
			i = skip_delimited_identifier(cs, i)
		} else if cs[i] == `:` {
			// A host parameter name isn't a keyword.
			i++
			for i < cs.len && is_identifier_char(cs[i], true) {
				i++
			}
		} else if is_identifier_char(cs[i], false) {
			start := i
			for i < cs.len && is_identifier_char(cs[i], true) {
				i++
			}
			word := cs[start..i].string().to_upper()
			words++
			if words == 1 && word != 'SELECT' {
				return text, ''
			}
			if depth == 0 && word == 'INTO' && into_start < 0 {
				into_start = start
				into_end = i
			} else if depth == 0 && word == 'FROM' && into_start >= 0 {
				from = start
				break
			}
		} else {
			if cs[i] == `(` {
				depth++
			} else if cs[i] == `)` {
				depth--
			}
			i++
		}
	}

	if into_start < 0 {
		return text, ''
	}

	return cs[..into_start].string() + ' ' + cs[from..].string(), cs[into_end..from].string()
}

// SelectTarget is a <target specification> in the <select target list>. The
// indicator is empty when there's no <indicator parameter>.
struct SelectTarget {
	parameter HostParameterDeclaration
	indicator string
}

// select_statement compiles a <select statement: single row>. The query is a
// <query specification> (Syntax Rule 4) without INTO and the targets.
fn select_statement(query string, targets_text string, p ExternallyInvokedProcedure) !ModuleStatement {
	targets := select_target_list(targets_text, p)!

	text_sql, references := rewrite_host_parameters(query, p)!
	stmt := parse_tokens(tokenize(text_sql)!) or { return procedure_error(p, err) }

	// - SR 4. The query must be a <query specification>, which can't have
	// ORDER BY, OFFSET or FETCH. The statement starts with SELECT, so it's a
	// query.
	query_expression := stmt as QueryExpression
	body := query_expression.body
	if body !is QuerySpecification || query_expression.order.len > 0
		|| query_expression.fetch != none || query_expression.offset != none {
		return sqlstate_42601('procedure ${p.name}: SELECT ... INTO cannot have UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH')
	}
	columns := select_list_degree((body as QuerySpecification).exprs)

	// - SR 3.b.i. The number of elements in the <select list> must be the
	// number of targets. A row type target (SR 3.a) has no C data type. With
	// an asterisk, it's checked when the query is executed.
	if columns >= 0 && columns != targets.len {
		are := if targets.len == 1 { 'is' } else { 'are' }
		return sqlstate_42601('procedure ${p.name}: the select list has ${columns} ${pluralize(columns, 'column')}, but there ${are} ${targets.len} ${pluralize(targets.len, 'target')}')
	}

	mut b := bind_parameters(['connection', 'execute', 'select'], references, p)!
	mut elements := []string{}
	mut assignments := ''
	for i, target in targets {
		typ := target.parameter.typ or { HostParameterType{} }
		has_indicator := if target.indicator == '' { 0 } else { 1 }
		elements << '    ${typ.c_target(target.parameter.name, has_indicator)}'
		if target.parameter.name.to_upper() !in b.used {
			b.used << target.parameter.name.to_upper()
		}
		if target.indicator != '' {
			indicator := p.indicator(target.indicator)!
			if indicator.name.to_upper() !in b.used {
				b.used << indicator.name.to_upper()
			}
			indicator_type := indicator.typ or { HostParameterType{} }
			assignments += '    *${indicator.name} = (${indicator_type.c_type()})vsql_m_t[${i}].indicator;\n'
		}
	}

	mut c := begin('SELECT', 65) + b.c + '  struct vsql_m_target vsql_m_t[${targets.len}] = {\n${elements.join(',\n')}};\n'
	call := 'vsql_m_select(SQLSTATE, ${c_string(text_sql.trim_space())}, ${b.args()}, ${targets.len}, vsql_m_t)'
	if assignments == '' {
		c += '  ${call};\n'
	} else {
		c += '  if (${call}) {\n${assignments}  }\n'
	}

	return ModuleStatement{b.sections, b.used, c}
}

// select_list_degree is the number of columns of a <select list>, or -1 if it
// has an asterisk.
fn select_list_degree(exprs SelectList) int {
	if exprs is []SelectSublist {
		for e in exprs {
			if e is QualifiedAsteriskExpr {
				return -1
			}
		}

		return exprs.len
	}

	return -1
}

// select_target_list reads the <select target list>. Each <target
// specification> is a host parameter (Syntax Rule 1), with an optional
// <indicator parameter>.
fn select_target_list(text string, p ExternallyInvokedProcedure) ![]SelectTarget {
	mut t := new_module_tokens(text)!
	mut targets := []SelectTarget{}
	for {
		if !t.accept(':') {
			return sqlstate_42601('procedure ${p.name}: expected a host parameter after INTO${t.near()}')
		}
		parameter := p.reference(t.c_name('host parameter name')!)!

		mut indicator := ''
		if t.accept('INDICATOR') {
			t.expect(':')!
			indicator = t.c_name('indicator parameter')!
		} else if t.accept(':') {
			indicator = t.c_name('indicator parameter')!
		}
		targets << SelectTarget{parameter, indicator}

		if !t.accept(',') {
			break
		}
	}

	if t.pos < t.tokens.len {
		return sqlstate_42601('procedure ${p.name}: expected FROM${t.near()}')
	}

	return targets
}
