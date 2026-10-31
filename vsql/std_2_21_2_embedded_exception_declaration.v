module vsql

// ISO/IEC 9075-2:2016(E), 21.2, <embedded exception declaration>
//
// WHENEVER is the action after each later <SQL procedure statement> that
// raises a condition. Only the <major category>s are supported (SQLSTATE and
// CONSTRAINT are Feature B041).

// EmbeddedExceptionDeclarations is the C label of the GOTO for each <major
// category> (SR 2), or empty for CONTINUE.
struct EmbeddedExceptionDeclarations {
mut:
	sqlexception string
	sqlwarning   string
	not_found    string
}

// declare reads the rest of a WHENEVER.
fn (mut w EmbeddedExceptionDeclarations) declare(mut t ModuleTokens) ! {
	category := t.next_word()
	if category !in ['SQLEXCEPTION', 'SQLWARNING', 'NOT'] || (category == 'NOT' && !t.accept('FOUND')) {
		t.pos--
		return sqlstate_42601('expected SQLEXCEPTION, SQLWARNING or NOT FOUND${t.near()}')
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

	match category {
		'SQLEXCEPTION' { w.sqlexception = label }
		'SQLWARNING' { w.sqlwarning = label }
		else { w.not_found = label }
	}
}

// c_checks is the C after a statement that goes to the label of the category
// of its SQLSTATE (General Rule 1). SR 1. The categories are X (any class
// other than 00, 01 and 02), W (01) and N (02).
fn (w EmbeddedExceptionDeclarations) c_checks() string {
	mut s := ''
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
