module vsql

// ISO/IEC 9075-2:2016(E), 20.1, Description of SQL descriptor areas
//
// Specify the identifiers, data types, and codes used in SQL item descriptor
// areas.
//
// Feature B031, "Basic dynamic SQL", is only in an SQL-client module. The C
// runtime keeps each SQL descriptor area in an SQL-connection (the
// SQL-session), and uses the SQL/CLI to describe a prepared statement (from
// its IRD), to bind its dynamic parameters and to get the values of its
// columns.
//
// The concept is described by:
//
// ISO/IEC 9075-2:2016(E), 4.30.4, Dynamic SQL statements and descriptor areas

// The exact numeric and character string components of an SQL item descriptor
// area (Table 27), other than DATA. Each one is a C constant, such as
// VSQL_M_TYPE. NULL_ORDERING and SORT_DIRECTION are only for a PTF descriptor
// area.
//
// ISO/IEC 9075-2:2016(E), 20.1, Description of SQL descriptor areas, Syntax Rules, 1 and 2
const descriptor_number_items = ['TYPE', 'LENGTH', 'OCTET_LENGTH', 'PRECISION', 'SCALE',
	'DATETIME_INTERVAL_CODE', 'DATETIME_INTERVAL_PRECISION', 'NULLABLE', 'UNNAMED', 'LEVEL',
	'KEY_MEMBER', 'INDICATOR', 'RETURNED_LENGTH', 'RETURNED_OCTET_LENGTH', 'CARDINALITY', 'DEGREE',
	'PARAMETER_MODE', 'PARAMETER_ORDINAL_POSITION', 'RETURNED_CARDINALITY', 'USER_DEFINED_TYPE_CODE']

const descriptor_string_items = ['NAME', 'CHARACTER_SET_CATALOG', 'CHARACTER_SET_SCHEMA',
	'CHARACTER_SET_NAME', 'COLLATION_CATALOG', 'COLLATION_SCHEMA', 'COLLATION_NAME',
	'PARAMETER_SPECIFIC_CATALOG', 'PARAMETER_SPECIFIC_SCHEMA', 'PARAMETER_SPECIFIC_NAME',
	'SCOPE_CATALOG', 'SCOPE_SCHEMA', 'SCOPE_NAME', 'USER_DEFINED_TYPE_CATALOG',
	'USER_DEFINED_TYPE_SCHEMA', 'USER_DEFINED_TYPE_NAME']

// The components that a <set descriptor statement> can't set, for a
// <conventional descriptor name>.
//
// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, Syntax Rules, 3.a and 3.b
const descriptor_read_only_items = ['RETURNED_LENGTH', 'RETURNED_OCTET_LENGTH', 'RETURNED_CARDINALITY',
	'OCTET_LENGTH', 'NULLABLE', 'KEY_MEMBER', 'UNNAMED', 'PARAMETER_MODE', 'PARAMETER_ORDINAL_POSITION',
	'PARAMETER_SPECIFIC_CATALOG', 'PARAMETER_SPECIFIC_SCHEMA', 'PARAMETER_SPECIFIC_NAME',
	'USER_DEFINED_TYPE_CODE', 'COLLATION_CATALOG', 'COLLATION_SCHEMA', 'COLLATION_NAME', 'NAME']

// The order that the components are set in.
//
// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 4
const descriptor_set_order = ['LEVEL', 'NAME', 'TYPE', 'DATETIME_INTERVAL_CODE',
	'DATETIME_INTERVAL_PRECISION', 'PRECISION', 'SCALE', 'CHARACTER_SET_CATALOG', 'CHARACTER_SET_SCHEMA',
	'CHARACTER_SET_NAME', 'COLLATION_CATALOG', 'COLLATION_SCHEMA', 'COLLATION_NAME',
	'USER_DEFINED_TYPE_CATALOG', 'USER_DEFINED_TYPE_SCHEMA', 'USER_DEFINED_TYPE_NAME', 'SCOPE_CATALOG',
	'SCOPE_SCHEMA', 'SCOPE_NAME', 'LENGTH', 'INDICATOR', 'DEGREE', 'CARDINALITY', 'DATA']

// The default <occurrences> of an <allocate descriptor statement>.
//
// ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, Syntax Rules, 2
const default_descriptor_occurrences = 100

// descriptor_name reads a <descriptor name>, and returns its C arguments: the
// name, and the module (or NULL for a GLOBAL name). Without Feature B032,
// "Extended dynamic SQL", it's an identifier (a <non-extended descriptor name>,
// which is Feature B035), or an <extended descriptor name> that's a literal.
// The scope of an extended name is LOCAL unless it's GLOBAL (ISO/IEC
// 9075-2:2016(E), 5.4, Names and identifiers, Syntax Rules, 26 and 27).
fn (mut t ModuleTokens) descriptor_name(p ExternallyInvokedProcedure) !string {
	mut module := '&vsql_m_own'
	mut extended := false
	if t.accept('GLOBAL') {
		module = 'NULL'
		extended = true
	} else if t.accept('LOCAL') {
		extended = true
	}

	if tok := t.peek() {
		if tok.kind == .literal {
			t.pos++
			// The literal (without leading or trailing spaces) must be an
			// identifier.
			//
			// ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, General Rules, 1.a
			mut n := new_module_tokens(tok.text.trim(' '))!
			name := n.identifier('descriptor name') or { '' }
			if name == '' || n.pos < n.tokens.len {
				return sqlstate_42601("procedure ${p.name}: '${tok.text}' is not a valid descriptor name")
			}

			return '${c_string(name)}, ${module}'
		}
	}

	if extended || t.accept(':') {
		return sqlstate_42601('procedure ${p.name}: a descriptor name must be an identifier or a literal${t.near()}')
	}

	return '${c_string(t.identifier('descriptor name')!)}, ${module}'
}

// descriptor_keyword reads "[ SQL ] DESCRIPTOR".
fn (mut t ModuleTokens) descriptor_keyword(p ExternallyInvokedProcedure) ! {
	t.accept('SQL')
	if !t.accept('DESCRIPTOR') {
		return sqlstate_42601('procedure ${p.name}: expected DESCRIPTOR${t.near()}')
	}
}

// allocate_descriptor_statement compiles an <allocate descriptor statement>,
// after ALLOCATE. <occurrences> can be a host parameter, which is Feature B032,
// "Extended dynamic SQL", as an extension.
//
// ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, Syntax Rules, 1 and 2
// ISO/IEC 9075-2:2016(E), 20.2, <allocate descriptor statement>, Conformance Rules, 1
fn (mut t ModuleTokens) allocate_descriptor_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	t.descriptor_keyword(p)!
	name := t.descriptor_name(p)!
	mut used := []string{}
	mut occurrences := '${default_descriptor_occurrences}LL'
	if t.accept('WITH') {
		t.expect('MAX')!
		occurrences = t.exact_numeric_value(p, mut used, 'number of occurrences', false)!
	}
	t.end_of_statement(p)!

	return ModuleStatement{['allocate_descriptor'], used, begin('ALLOCATE DESCRIPTOR', 2) +
		'  vsql_m_allocate_descriptor(SQLSTATE, ${name}, ${occurrences});\n'}
}

// deallocate_descriptor_statement compiles a <deallocate descriptor statement>,
// after DEALLOCATE.
//
// ISO/IEC 9075-2:2016(E), 20.3, <deallocate descriptor statement>
fn (mut t ModuleTokens) deallocate_descriptor_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	t.descriptor_keyword(p)!
	name := t.descriptor_name(p)!
	t.end_of_statement(p)!

	return ModuleStatement{['deallocate_descriptor'], [], begin('DEALLOCATE DESCRIPTOR', 15) +
		'  vsql_m_deallocate_descriptor(SQLSTATE, ${name});\n'}
}

// DescriptorAssignment is a <get header information>, <get item information>,
// <set header information> or <set item information>.
struct DescriptorAssignment {
	parameter HostParameterDeclaration
	item      string
}

// get_descriptor_statement compiles a <get descriptor statement>, after GET.
// Each value is assigned to its target, so a number must be assigned to an
// exact numeric, and a string to a CHARACTER or CHARACTER VARYING (which is
// truncated with a warning).
//
// ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, Syntax Rules, 1 to 3
// ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, General Rules, 7.a and 7.b
fn (mut t ModuleTokens) get_descriptor_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	t.descriptor_keyword(p)!
	name := t.descriptor_name(p)!
	mut used := []string{}
	mut sections := []string{}
	mut c := '  int vsql_m_w = 0;\n' + begin('GET DESCRIPTOR', 47)

	if t.accept('VALUE') {
		n := t.exact_numeric_value(p, mut used, 'item number', false)!
		assignments := t.descriptor_assignments(p, false)!
		sections << 'get_item'

		// The target of DATA can be any data type (the C runtime checks that it
		// matches), and every other component is a number or a string.
		//
		// ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, Syntax Rules, 3
		mut data := '0, 0'
		mut indicator := 0
		mut gets := ''
		for a in assignments {
			typ := a.parameter.typ or { HostParameterType{} }
			used << a.parameter.name.to_upper()
			if a.item == 'DATA' {
				sections << 'get_data'
				data = '${typ.c_code()}, ${typ.length}'
				gets += '  vsql_m_w |= vsql_m_get_data(vsql_m_i, ${a.parameter.name}, ${typ.c_code()}, ${typ.length});\n'
			} else if a.item in descriptor_number_items {
				if a.item == 'INDICATOR' {
					indicator = 1
				}
				gets += t.get_number(p, a.parameter, 'vsql_m_i->number[VSQL_M_${a.item}]', a.item)!
			} else {
				pad := if typ.typ == .is_character { 1 } else { 0 }
				sections << 'put'
				gets += t.get_string(p, a.parameter, 'vsql_m_i->string[VSQL_M_${a.item}] == NULL ? "" : vsql_m_i->string[VSQL_M_${a.item}]',
					pad, a.item)!
			}
		}

		c += '  struct vsql_m_item *vsql_m_i = vsql_m_get_item(SQLSTATE, ${name}, ${n}, ${data}, ${indicator});\n'
		c += '  if (vsql_m_i == NULL) {\n    return;\n  }\n' + gets
	} else {
		assignments := t.descriptor_assignments(p, true)!
		sections << 'descriptor'
		mut gets := ''
		for a in assignments {
			used << a.parameter.name.to_upper()
			typ := a.parameter.typ or { HostParameterType{} }
			pad := if typ.typ == .is_character { 1 } else { 0 }
			if a.item == 'DYNAMIC_FUNCTION' {
				sections << 'put'
				gets += t.get_string(p, a.parameter, 'vsql_m_d->dynamic_function', pad,
					a.item)!
			} else {
				// vsql doesn't know if a column is part of a key, so KEY_TYPE
				// is always 0 (zero) (#801).
				//
				// ISO/IEC 9075-2:2016(E), 20.10, <describe statement>, General Rules, 6.d
				field := match a.item {
					'COUNT' { 'vsql_m_d->count' }
					'KEY_TYPE' { '0' }
					else { 'vsql_m_d->${a.item.to_lower()}' }
				}
				gets += t.get_number(p, a.parameter, field, a.item)!
			}
		}

		c += '  struct vsql_m_descriptor *vsql_m_d = vsql_m_descriptor(SQLSTATE, ${name});\n'
		c += '  if (vsql_m_d == NULL) {\n    return;\n  }\n' + gets
	}

	return ModuleStatement{sections, used, c +
		'  vsql_m_status(SQLSTATE, vsql_m_w ? "01004" : "00000");\n'}
}

// get_number assigns a number to a target, which must be exact numeric.
fn (t ModuleTokens) get_number(p ExternallyInvokedProcedure, parameter HostParameterDeclaration, value string, item string) !string {
	typ := parameter.typ or { HostParameterType{} }
	if !typ.is_exact_numeric() {
		return sqlstate_42601('procedure ${p.name}: host parameter :${parameter.name} must be SMALLINT, INTEGER or BIGINT for ${item}')
	}

	return '  *${parameter.name} = (${typ.c_type()})${value};\n'
}

// get_string assigns a string to a target, which must be CHARACTER or CHARACTER
// VARYING.
fn (t ModuleTokens) get_string(p ExternallyInvokedProcedure, parameter HostParameterDeclaration, value string, pad int, item string) !string {
	typ := parameter.typ or { HostParameterType{} }
	if !typ.is_string() {
		return sqlstate_42601('procedure ${p.name}: host parameter :${parameter.name} must be CHARACTER or CHARACTER VARYING for ${item}')
	}

	return '  vsql_m_w |= vsql_m_put(${parameter.name}, ${typ.length}, ${pad}, ${value});\n'
}

// descriptor_assignments reads the <get header information>s or <get item
// information>s of a <get descriptor statement>.
fn (mut t ModuleTokens) descriptor_assignments(p ExternallyInvokedProcedure, header bool) ![]DescriptorAssignment {
	mut assignments := []DescriptorAssignment{}
	for {
		if !t.accept(':') {
			return sqlstate_42601('procedure ${p.name}: expected a host parameter${t.near()}')
		}
		parameter := p.reference(t.c_name('host parameter name')!)!
		t.expect('=')!
		item := t.descriptor_item(p, header)!
		assignments << DescriptorAssignment{parameter, item}

		if !t.accept(',') {
			break
		}
	}

	return assignments
}

// descriptor_item reads a <header item name> or a <descriptor item name>.
// NULL_ORDERING and SORT_DIRECTION are only for a PTF descriptor area (Feature
// B209, "PTF extended names").
//
// ISO/IEC 9075-2:2016(E), 20.4, <get descriptor statement>, Conformance Rules, 4
fn (mut t ModuleTokens) descriptor_item(p ExternallyInvokedProcedure, header bool) !string {
	item := t.next_word()
	if header {
		if item in ['COUNT', 'KEY_TYPE', 'DYNAMIC_FUNCTION', 'DYNAMIC_FUNCTION_CODE', 'TOP_LEVEL_COUNT'] {
			return item
		}
		t.pos--
		return sqlstate_42601('procedure ${p.name}: expected a header item name${t.near()}')
	}

	if item == 'DATA' || item in descriptor_number_items || item in descriptor_string_items {
		return item
	}
	t.pos--

	return sqlstate_42601('procedure ${p.name}: expected a descriptor item name${t.near()}')
}

// set_descriptor_statement compiles a <set descriptor statement>, after SET.
//
// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>
fn (mut t ModuleTokens) set_descriptor_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	t.descriptor_keyword(p)!
	name := t.descriptor_name(p)!
	mut used := []string{}
	mut c := begin('SET DESCRIPTOR', 70)

	// COUNT is the only header item that can be set.
	//
	// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, Syntax Rules, 2
	if !t.accept('VALUE') {
		t.expect('COUNT')!
		t.expect('=')!
		value := t.exact_numeric_value(p, mut used, 'value', true)!
		t.end_of_statement(p)!

		return ModuleStatement{['set_count'], used, c +
			'  vsql_m_set_count(SQLSTATE, ${name}, ${value});\n'}
	}

	n := t.exact_numeric_value(p, mut used, 'item number', false)!
	mut sections := ['set_item']
	mut a := ConnectionArguments{}
	mut values := map[string]string{}
	for {
		item := t.descriptor_item(p, false)!
		// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, Syntax Rules, 3.a to 3.c
		if item in descriptor_read_only_items {
			return sqlstate_42601('procedure ${p.name}: ${item} cannot be set')
		}
		if item in values {
			return sqlstate_42601('procedure ${p.name}: ${item} is set more than once')
		}
		t.expect('=')!

		if item == 'DATA' {
			// DATA can't be set to a literal.
			//
			// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, Syntax Rules, 4
			if !t.accept(':') {
				return sqlstate_42601('procedure ${p.name}: DATA must be set to a host parameter${t.near()}')
			}
			parameter := p.reference(t.c_name('host parameter name')!)!
			typ := parameter.typ or { HostParameterType{} }
			used << parameter.name.to_upper()
			if typ.is_string() {
				a.checks += '  if (!vsql_m_string(SQLSTATE, ${parameter.name}, ${typ.size()})) {\n    return;\n  }\n'
				sections << 'string'
			}
			sections << 'set_data'
			values[item] = 'vsql_m_set_data(SQLSTATE, vsql_m_i, ${typ.c_code()}, ${typ.length}, ${parameter.name})'
		} else if item in descriptor_number_items {
			// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, Syntax Rules, 3.d
			sections << 'set_number'
			value := t.exact_numeric_value(p, mut used, 'value', true)!
			values[item] = 'vsql_m_set_number(SQLSTATE, vsql_m_i, VSQL_M_${item}, ${value})'
		} else {
			sections << 'set_string'
			value := t.connection_value(p, mut a)!
			values[item] = 'vsql_m_set_string(vsql_m_i, VSQL_M_${item}, ${value})'
		}

		if !t.accept(',') {
			break
		}
	}
	t.end_of_statement(p)!
	used << a.parameters
	sections << a.sections

	// The values are set in a fixed order.
	//
	// ISO/IEC 9075-2:2016(E), 20.5, <set descriptor statement>, General Rules, 4
	mut calls := ['vsql_m_i != NULL']
	for item in descriptor_set_order {
		if call := values[item] {
			calls << call
		}
	}
	c += a.checks +
		'  struct vsql_m_item *vsql_m_i = vsql_m_set_item(SQLSTATE, ${name}, ${n});\n'
	c += '  if (${calls.join(' &&\n      ')}) {\n    vsql_m_status(SQLSTATE, "00000");\n  }\n'

	return ModuleStatement{sections, used, c}
}
