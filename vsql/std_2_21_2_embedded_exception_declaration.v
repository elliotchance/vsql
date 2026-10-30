module vsql

// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>
//
// WHENEVER is the action after each later <SQL procedure statement> that
// raises a condition. SQLSTATE and CONSTRAINT are Feature B041.
//
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, Conformance Rules, 1

// EmbeddedExceptionDeclarations are the <embedded exception declaration>s that
// apply to the next <SQL procedure statement>, and that GOTO a C label
// (CONTINUE does nothing). The C compiler checks that each label can be used
// where it's applied.
//
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, Syntax Rules, 2 and 5
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, General Rules, 1.a
struct EmbeddedExceptionDeclarations {
mut:
	// sqlexception, sqlwarning and not_found are the labels of the <major
	// category>s, or empty for CONTINUE.
	sqlexception string
	sqlwarning   string
	not_found    string
	// sqlstates is the label of each SQLSTATE class code, or class code and
	// subclass code (such as "22" or "22012").
	sqlstates map[string]string
	// constraints are the constraints, in the order that they were declared.
	constraints []EmbeddedConstraint
}

struct EmbeddedConstraint {
	// catalog is empty when the <constraint name> doesn't have one.
	catalog string
	schema  string
	name    string
	label   string
}

// declare reads the rest of a WHENEVER. schema is the default schema of the
// implied module, for a <constraint name> that isn't qualified. Any <SQLSTATE
// class code> and <SQLSTATE subclass code> can be used, including those of
// vsql that aren't in Table 38.
//
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, Syntax Rules, 4
fn (mut w EmbeddedExceptionDeclarations) declare(mut t ModuleTokens, schema string) ! {
	mut condition := ''
	mut constraint := EmbeddedConstraint{}
	if t.accept('SQLSTATE') {
		t.expect('(')!
		condition = t.sqlstate_code('class code', 2)!
		if condition == '00' {
			return sqlstate_42601('SQLSTATE class 00 is successful completion, which is not a condition')
		}
		if t.accept(',') {
			condition += t.sqlstate_code('subclass code', 3)!
		}
		t.expect(')')!
	} else if t.accept('CONSTRAINT') {
		mut parts := [t.identifier('a constraint name')!]
		for parts.len < 3 && t.accept('.') {
			parts.prepend(t.identifier('a constraint name')!)
		}
		constraint = EmbeddedConstraint{
			catalog: if parts.len == 3 { parts[2] } else { '' }
			schema:  if parts.len > 1 { parts[1] } else { schema }
			name:    parts[0]
		}
		condition = 'CONSTRAINT'
	} else {
		condition = t.next_word()
		if condition !in ['SQLEXCEPTION', 'SQLWARNING', 'NOT']
			|| (condition == 'NOT' && !t.accept('FOUND')) {
			t.pos--
			return sqlstate_42601('expected SQLEXCEPTION, SQLWARNING, NOT FOUND, SQLSTATE or CONSTRAINT${t.near()}')
		}
	}

	mut label := ''
	action := t.next_word()
	if action == 'GOTO' || (action == 'GO' && t.accept('TO')) {
		label = t.c_name('a label')!
	} else if action != 'CONTINUE' {
		t.pos--
		return sqlstate_42601('expected CONTINUE, GOTO or GO TO${t.near()}')
	}
	if t.peek() != none {
		return sqlstate_42601('unexpected${t.near()}')
	}

	// A declaration no longer applies after another one with the same
	// condition, or with a condition that includes it.
	//
	// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, Syntax Rules, 2.a to 2.d
	w.constraints = w.constraints.filter(!(condition == 'SQLEXCEPTION' || condition == '23'
		|| (condition == 'CONSTRAINT' && it.catalog == constraint.catalog
			&& it.schema == constraint.schema && it.name == constraint.name)))
	for code in w.sqlstates.keys() {
		if code == condition || code[..2] == condition
			|| (condition == 'SQLEXCEPTION' && code[..2] !in ['01', '02'])
			|| (condition == 'SQLWARNING' && code[..2] == '01')
			|| (condition == 'NOT' && code[..2] == '02') {
			w.sqlstates.delete(code)
		}
	}

	match condition {
		'SQLEXCEPTION' {
			w.sqlexception = label
		}
		'SQLWARNING' {
			w.sqlwarning = label
		}
		'NOT' {
			w.not_found = label
		}
		'CONSTRAINT' {
			if label != '' {
				w.constraints << EmbeddedConstraint{
					...constraint
					label: label
				}
			}
		}
		else {
			if label != '' {
				w.sqlstates[condition] = label
			}
		}
	}
}

// sqlstate_code reads an <SQLSTATE class code> or <SQLSTATE subclass code>,
// which may be more than one token (such as 2B), but there can't be a
// <separator> in it.
//
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, Syntax Rules, 3
fn (mut t ModuleTokens) sqlstate_code(what string, length int) !string {
	mut code := ''
	for {
		tok := t.peek() or { break }
		if tok.kind !in [.word, .number] || (code != '' && tok.start != t.tokens[t.pos - 1].start +
			t.tokens[t.pos - 1].text.len) {
			break
		}
		code += tok.text
		t.pos++
	}
	if code == '' {
		return sqlstate_42601('expected SQLSTATE ${what}${t.near()}')
	}
	if code.len != length || !code.bytes().all((it >= `0` && it <= `9`) || (it >= `A` && it <= `Z`)) {
		return sqlstate_42601('SQLSTATE ${what} must be ${length} digits or upper case letters: ${code}')
	}

	return code
}

// c_checks is the C after a statement that goes to the label of the condition
// that it raised: a violated constraint, then the SQLSTATE, then its class,
// then its category. The categories are X (any class other than 00, 01 and
// 02), W (01) and N (02). None of them is successful completion (00).
//
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, General Rules, 1 and 1.b
// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>, General Rules, 1.d.i to 1.d.iii
fn (w EmbeddedExceptionDeclarations) c_checks() string {
	mut s := ''
	for c in w.constraints {
		catalog := if c.catalog == '' { 'NULL' } else { c_string(c.catalog) }
		s += ' if (vsql_m_violated(${catalog}, ${c_string(c.schema)}, ${c_string(c.name)})) goto ${c.label};'
	}
	mut codes := w.sqlstates.keys()
	codes.sort()
	for length in [5, 2] {
		for code in codes.filter(it.len == length) {
			s += ' if (memcmp(SQLSTATE, "${code}", ${length}) == 0) goto ${w.sqlstates[code]};'
		}
	}
	if w.sqlexception != '' {
		s += " if (SQLSTATE[0] != '0' || SQLSTATE[1] > '2') goto ${w.sqlexception};"
	}
	if w.sqlwarning != '' {
		s += " if (SQLSTATE[0] == '0' && SQLSTATE[1] == '1') goto ${w.sqlwarning};"
	}
	if w.not_found != '' {
		s += " if (SQLSTATE[0] == '0' && SQLSTATE[1] == '2') goto ${w.not_found};"
	}

	return s
}
