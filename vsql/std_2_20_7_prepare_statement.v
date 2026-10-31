module vsql

// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>
//
// Prepare a statement for execution.
//
// In an SQL-client module (Feature B031, "Basic dynamic SQL"), each prepared
// statement is a CLI statement that's prepared with SQLPrepare. The other <SQL
// dynamic statement>s that use it are here too.
//
// The concepts are described by:
//
// ISO/IEC 9075-2:2016(E), 4.30, Dynamic SQL concepts
// ISO/IEC 9075-2:2016(E), 4.39.7, Preparable and immediately executable SQL-statements

// prepared_statement_names are the <statement name>s of the <prepare
// statement>s in the statements of a module.
fn prepared_statement_names(statements []string) []string {
	mut names := []string{}
	for statement in statements {
		mut t := new_module_tokens(statement) or { continue }
		if t.accept('PREPARE') {
			names << t.identifier('statement name') or { continue }
		}
	}

	return names
}

// statement_name reads a <statement name>, which must be the name of a <prepare
// statement> in the module. An <extended statement name> (a host parameter) is
// Feature B032, "Extended dynamic SQL".
//
// ISO/IEC 9075-2:2016(E), 20.9, <deallocate prepared statement>, Syntax Rules, 1.b
// ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, Syntax Rules, 1.b
// ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, Syntax Rules, 1.b
// ISO/IEC 9075-2:2016(E), 20.15, <dynamic declare cursor>, Syntax Rules, 2
fn (mut t ModuleTokens) statement_name(p ExternallyInvokedProcedure, prepared []string) !string {
	name := t.identifier('statement name')!
	if name !in prepared {
		return sqlstate_42601('procedure ${p.name}: statement ${name} is not prepared in the module')
	}

	return name
}

// prepare_statement compiles a <prepare statement>, after PREPARE. The <SQL
// statement variable> is a host parameter that is a CHARACTER or CHARACTER
// VARYING, or (as an extension) a literal. An <attributes specification> is
// Feature B034, "Dynamic specification of cursor attributes".
//
// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, Syntax Rules, 1 and 2
// ISO/IEC 9075-2:2016(E), 20.7, <prepare statement>, Conformance Rules, 2
fn (mut t ModuleTokens) prepare_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	name := t.identifier('statement name')!
	t.expect('FROM')!
	mut a := ConnectionArguments{
		sections: ['prepare']
	}
	sql := t.connection_value(p, mut a)!
	t.end_of_statement(p)!

	return ModuleStatement{a.sections, a.parameters, begin('PREPARE', 56) + a.checks +
		'  vsql_m_prepare(SQLSTATE, ${c_string(name)}, ${sql});\n'}
}

// deallocate_prepared_statement compiles a <deallocate prepared statement>,
// after DEALLOCATE PREPARE.
//
// ISO/IEC 9075-2:2016(E), 20.9, <deallocate prepared statement>
fn (mut t ModuleTokens) deallocate_prepared_statement(p ExternallyInvokedProcedure, prepared []string) !ModuleStatement {
	name := t.statement_name(p, prepared)!
	t.end_of_statement(p)!

	return ModuleStatement{['deallocate_prepare'], [], begin('DEALLOCATE PREPARE', 16) +
		'  vsql_m_deallocate_prepare(SQLSTATE, ${c_string(name)});\n'}
}

// describe_statement compiles a <describe output statement>, after DESCRIBE. A
// <describe input statement> is Feature B032-01, and the structure of a
// received cursor is Feature T472, "DESCRIBE CURSOR". vsql doesn't have a ROW,
// ARRAY or MULTISET, so WITH NESTING doesn't change anything.
//
// ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, Syntax Rules, 2
// ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, Conformance Rules, 1 to 3
fn (mut t ModuleTokens) describe_statement(p ExternallyInvokedProcedure, prepared []string) !ModuleStatement {
	if t.accept('INPUT') {
		return sqlstate_42601('procedure ${p.name}: DESCRIBE INPUT is not supported')
	}
	t.accept('OUTPUT')
	name := t.statement_name(p, prepared)!
	t.expect('USING')!
	t.descriptor_keyword(p)!
	descriptor := t.descriptor_name(p)!
	if t.accept('WITH') || t.accept('WITHOUT') {
		t.expect('NESTING')!
	}
	t.end_of_statement(p)!

	return ModuleStatement{['describe'], [], begin('DESCRIBE', 20) +
		'  vsql_m_describe(SQLSTATE, ${c_string(name)}, ${descriptor});\n'}
}

// execute_statement compiles an <execute statement>, after EXECUTE. Its <result
// using clause> is before its <parameter using clause>.
//
// ISO/IEC 9075-2:2016(E), 20.13, <execute statement>
fn (mut t ModuleTokens) execute_statement(p ExternallyInvokedProcedure, prepared []string) !ModuleStatement {
	name := t.statement_name(p, prepared)!
	mut b := BoundParameters{
		sections: ['execute_prepared']
	}
	output, assignments := t.output_using_clause(p, mut b)!
	input := t.input_using_clause(p, mut b)!
	t.end_of_statement(p)!
	call := 'vsql_m_execute_prepared(SQLSTATE, ${c_string(name)}, &vsql_m_in, &vsql_m_out)'

	return ModuleStatement{b.sections, b.used, begin('EXECUTE', 44) + input + output +
		assign_targets(call, assignments)}
}

// execute_immediate_statement compiles an <execute immediate statement>, after
// EXECUTE IMMEDIATE. The <SQL statement variable> is the same as a <prepare
// statement>.
//
// ISO/IEC 9075-2:2016(E), 20.14, <execute immediate statement>, Syntax Rules, 1
fn (mut t ModuleTokens) execute_immediate_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	mut a := ConnectionArguments{
		sections: ['execute_immediate']
	}
	sql := t.connection_value(p, mut a)!
	t.end_of_statement(p)!

	return ModuleStatement{a.sections, a.parameters, begin('EXECUTE IMMEDIATE', 43) + a.checks +
		'  vsql_m_execute_immediate(SQLSTATE, ${sql});\n'}
}

// input_using_clause compiles an optional <input using clause>, which is the
// struct vsql_m_input (vsql_m_in) of the C runtime. Each <using argument> is a
// host parameter, with an optional indicator parameter.
//
// ISO/IEC 9075-2:2016(E), 20.11, <input using clause>, Syntax Rules, 1
fn (mut t ModuleTokens) input_using_clause(p ExternallyInvokedProcedure, mut b BoundParameters) !string {
	if !t.accept('USING') {
		return '  struct vsql_m_input vsql_m_in = {-1, NULL, NULL, NULL};\n'
	}

	if t.accept_descriptor_keyword()! {
		return '  struct vsql_m_input vsql_m_in = {0, NULL, ${t.descriptor_name(p)!}};\n'
	}

	mut references := []HostParameterReference{}
	for target in t.target_list(p, 'USING')! {
		references << HostParameterReference{target.parameter.name, target.indicator}
	}
	bound := bind_parameters([], references, p)!
	b.sections << bound.sections
	b.used << bound.used

	return bound.c + '  struct vsql_m_input vsql_m_in = {${bound.args()}, NULL, NULL};\n'
}

// accept_descriptor_keyword reads "SQL DESCRIPTOR" or "DESCRIPTOR", if it's
// next.
fn (mut t ModuleTokens) accept_descriptor_keyword() !bool {
	if t.accept('SQL') {
		t.expect('DESCRIPTOR')!
		return true
	}

	return t.accept('DESCRIPTOR')
}

// output_using_clause compiles an optional <output using clause>, which is the
// struct vsql_m_output (vsql_m_out) of the C runtime, and the C that assigns
// the indicator parameters. Each <into argument> is a host parameter, with an
// optional indicator parameter. A <result using clause> is Feature B032,
// "Extended dynamic SQL", but it's allowed as an extension.
//
// ISO/IEC 9075-2:2016(E), 20.12, <output using clause>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 20.13, <execute statement>, Conformance Rules, 1
fn (mut t ModuleTokens) output_using_clause(p ExternallyInvokedProcedure, mut b BoundParameters) !(string, string) {
	if !t.accept('INTO') {
		return '  struct vsql_m_output vsql_m_out = {-1, NULL, NULL, NULL};\n', ''
	}

	if t.accept_descriptor_keyword()! {
		return '  struct vsql_m_output vsql_m_out = {0, NULL, ${t.descriptor_name(p)!}};\n', ''
	}

	targets := t.target_list(p, 'INTO')!
	targets_c, assignments := bind_targets(targets, p, mut b)!

	return targets_c + '  struct vsql_m_output vsql_m_out = {${targets.len}, vsql_m_t, NULL, NULL};\n', assignments
}

// dynamic_open_statement compiles a <dynamic open statement>, after OPEN and
// the cursor name, which is a declared dynamic cursor.
//
// ISO/IEC 9075-2:2016(E), 20.19, <dynamic open statement>, Syntax Rules, 1
fn (mut t ModuleTokens) dynamic_open_statement(p ExternallyInvokedProcedure, cursor ModuleCursor) !ModuleStatement {
	mut b := BoundParameters{
		sections: ['open_dynamic']
	}
	input := t.input_using_clause(p, mut b)!
	t.end_of_statement(p)!
	hold := if cursor.hold { 1 } else { 0 }

	return ModuleStatement{b.sections, b.used, begin('DYNAMIC OPEN', 40) + input +
		'  vsql_m_open_dynamic(SQLSTATE, ${cursor.index}, ${c_string(cursor.sql_name)}, ${hold}, ${c_string(cursor.statement)}, &vsql_m_in);\n'}
}

// dynamic_fetch_statement compiles a <dynamic fetch statement>, after the
// cursor name, which is a declared dynamic cursor. The <fetch orientation> can
// only be NEXT (see fetch_statement), since there are no scrollable cursors
// (F431).
//
// ISO/IEC 9075-2:2016(E), 20.20, <dynamic fetch statement>, Syntax Rules, 1 and 2
fn (mut t ModuleTokens) dynamic_fetch_statement(p ExternallyInvokedProcedure, cursor ModuleCursor) !ModuleStatement {
	t.expect('INTO')!
	t.pos--
	mut b := BoundParameters{
		sections: ['fetch_dynamic']
	}
	output, assignments := t.output_using_clause(p, mut b)!
	t.end_of_statement(p)!
	call := 'vsql_m_fetch_dynamic(SQLSTATE, ${cursor.index}, &vsql_m_out)'

	return ModuleStatement{b.sections, b.used, begin('DYNAMIC FETCH', 39) + output +
		assign_targets(call, assignments)}
}
