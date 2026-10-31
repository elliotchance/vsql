module vsql

// ISO/IEC 9075-2:2016(E), 13.3, <externally-invoked procedure>
//
// Define an externally-invoked procedure.
//
// The concept is described by ISO/IEC 9075-1:2003(E), 4.8.2.5, Indicator
// parameters.
//
// The concepts are also described by:
//
// ISO/IEC 9075-2:2016(E), 4.32, Externally-invoked procedures
// ISO/IEC 9075-2:2016(E), 4.35, Host parameters

struct ExternallyInvokedProcedure {
	// The name, and the names of the host parameters, are kept as they were
	// written since they're also the C names.
	name       string
	parameters []HostParameterDeclaration
mut:
	statement ModuleStatement
}

// HostParameterDeclaration is a <host parameter declaration>. The status
// parameter (SQLSTATE) has no type.
struct HostParameterDeclaration {
	name string
	typ  ?HostParameterType
}

// procedure_declaration reads "PROCEDURE <procedure name> <host parameter
// declaration list>", which ends at the semicolon before the statement.
fn (mut t ModuleTokens) procedure_declaration() !ExternallyInvokedProcedure {
	t.expect('PROCEDURE')!
	name := t.c_name('procedure name')!

	t.expect('(')!
	mut parameters := []HostParameterDeclaration{}
	mut has_status := false
	for {
		if t.accept('SQLSTATE') {
			// There must be exactly one status parameter.
			//
			// ISO/IEC 9075-2:2016(E), 13.3, <externally-invoked procedure>, Syntax Rules, 7
			if has_status {
				return sqlstate_42601('procedure ${name}: SQLSTATE can only be used once')
			}
			has_status = true
			parameters << HostParameterDeclaration{'SQLSTATE', none}
		} else {
			t.expect(':')!
			parameter := t.c_name('host parameter name')!

			// Each host parameter has a different name.
			//
			// ISO/IEC 9075-2:2016(E), 13.3, <externally-invoked procedure>, Syntax Rules, 2
			for p in parameters {
				if p.name.to_upper() == parameter.to_upper() {
					return sqlstate_42601('procedure ${name}: host parameter :${parameter} is declared more than once')
				}
			}

			parameters << HostParameterDeclaration{parameter, t.host_parameter_type(parameter)!}
		}

		if !t.accept(',') {
			break
		}
	}
	t.expect(')')!

	if t.pos < t.tokens.len {
		return sqlstate_42601('procedure ${name}: expected ;${t.near()}')
	}
	if !has_status {
		return sqlstate_42601('procedure ${name}: SQLSTATE must be one of the parameters')
	}

	return ExternallyInvokedProcedure{
		name:       name
		parameters: parameters
	}
}

// parameter is the declaration of the host parameter called name (compared
// like an identifier), if there is one.
fn (p ExternallyInvokedProcedure) parameter(name string) ?HostParameterDeclaration {
	for parameter in p.parameters {
		if parameter.typ != none && parameter.name.to_upper() == name.to_upper() {
			return parameter
		}
	}

	return none
}

// c_prototype is the C declaration of the procedure. The C data type of each
// parameter is from Table 20, "Data type correspondences for C". A C compiler
// checks that a call has an argument of the right type for each parameter.
//
// ISO/IEC 9075-2:2016(E), 13.3, <externally-invoked procedure>, Syntax Rules, 6 and 11
fn (p ExternallyInvokedProcedure) c_prototype() string {
	mut parameters := []string{}
	for parameter in p.parameters {
		if typ := parameter.typ {
			parameters << typ.c_declaration(parameter.name)
		} else {
			// An SQLSTATE host parameter is a char with length 6.
			//
			// ISO/IEC 9075-2:2016(E), 13.3, <externally-invoked procedure>, Syntax Rules, 11.a
			parameters << 'char SQLSTATE[6]'
		}
	}

	return 'void ${p.name}(${parameters.join(', ')})'
}

// c_function is the C definition of the procedure. A host parameter that the
// statement doesn't use (which is neither an input nor an output host
// parameter) is cast to void, so that the C compiler doesn't warn about it. The
// status parameter is always an output host parameter.
//
// ISO/IEC 9075-2:2016(E), 9.8, Host parameter mode determination, Syntax Rules, 3.a and 3.b.v
fn (p ExternallyInvokedProcedure) c_function() string {
	mut s := '${p.c_prototype()} {\n'
	used := p.statement.parameters
	for parameter in p.parameters {
		if parameter.typ != none && parameter.name.to_upper() !in used {
			s += '  (void)${parameter.name};\n'
		}
	}

	return s + p.statement.c + '}\n\n'
}
