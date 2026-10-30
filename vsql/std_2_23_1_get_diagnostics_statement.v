module vsql

// ISO/IEC 9075-2:2016(E), 23.1, <get diagnostics statement>
//
// Get exception or completion condition information from a diagnostics area.
//
// It's only in an SQL-client module, where each target is a host parameter.
// The C runtime keeps the first diagnostics area, from the diagnostics areas
// that libvsql keeps for its handles.

// The C constant (in libvsql.h, or the C runtime) of each <statement
// information item name> and <condition information item name>. An empty
// constant is always 0 (zero) or a zero-length string, since vsql doesn't have
// the constraints, triggers, routines, etc. that it describes.
const statement_information_items = {
	'NUMBER':                   'SQL_DIAG_NUMBER'
	'MORE':                     'SQL_DIAG_MORE'
	'COMMAND_FUNCTION':         'VSQL_M_COMMAND_FUNCTION'
	'COMMAND_FUNCTION_CODE':    'VSQL_M_COMMAND_FUNCTION_CODE'
	'DYNAMIC_FUNCTION':         'VSQL_M_DYNAMIC_FUNCTION'
	'DYNAMIC_FUNCTION_CODE':    'VSQL_M_DYNAMIC_FUNCTION_CODE'
	'ROW_COUNT':                'SQL_DIAG_ROW_COUNT'
	'TRANSACTIONS_COMMITTED':   'SQL_DIAG_TRANSACTIONS_COMMITTED'
	'TRANSACTIONS_ROLLED_BACK': 'SQL_DIAG_TRANSACTIONS_ROLLED_BACK'
	'TRANSACTION_ACTIVE':       'SQL_DIAG_TRANSACTION_ACTIVE'
}

const condition_information_items = {
	'CATALOG_NAME':               ''
	'CLASS_ORIGIN':               'SQL_DIAG_CLASS_ORIGIN'
	'COLUMN_NAME':                ''
	'CONDITION_NUMBER':           ''
	'CONNECTION_NAME':            'SQL_DIAG_CONNECTION_NAME'
	'CONSTRAINT_CATALOG':         ''
	'CONSTRAINT_NAME':            ''
	'CONSTRAINT_SCHEMA':          ''
	'CURSOR_NAME':                ''
	'MESSAGE_LENGTH':             'SQL_DIAG_MESSAGE_LENGTH'
	'MESSAGE_OCTET_LENGTH':       'SQL_DIAG_MESSAGE_OCTET_LENGTH'
	'MESSAGE_TEXT':               'SQL_DIAG_MESSAGE_TEXT'
	'PARAMETER_MODE':             ''
	'PARAMETER_NAME':             ''
	'PARAMETER_ORDINAL_POSITION': ''
	'RETURNED_SQLSTATE':          'SQL_DIAG_SQLSTATE'
	'ROUTINE_CATALOG':            ''
	'ROUTINE_NAME':               ''
	'ROUTINE_SCHEMA':             ''
	'SCHEMA_NAME':                ''
	'SERVER_NAME':                'SQL_DIAG_SERVER_NAME'
	'SPECIFIC_NAME':              ''
	'SUBCLASS_ORIGIN':            'SQL_DIAG_SUBCLASS_ORIGIN'
	'TABLE_NAME':                 ''
	'TRIGGER_CATALOG':            ''
	'TRIGGER_NAME':               ''
	'TRIGGER_SCHEMA':             ''
}

// The items that are exact numeric (Table 35 and Table 36). The others are
// character strings.
const exact_numeric_diagnostics_items = ['NUMBER', 'COMMAND_FUNCTION_CODE', 'DYNAMIC_FUNCTION_CODE',
	'ROW_COUNT', 'TRANSACTIONS_COMMITTED', 'TRANSACTIONS_ROLLED_BACK', 'TRANSACTION_ACTIVE',
	'CONDITION_NUMBER', 'MESSAGE_LENGTH', 'MESSAGE_OCTET_LENGTH', 'PARAMETER_ORDINAL_POSITION']

// get_diagnostics_statement compiles a <get diagnostics statement>, after GET
// DIAGNOSTICS. Unlike any other statement, it doesn't empty the first
// diagnostics area (13.4 General Rule 6).
fn (mut t ModuleTokens) get_diagnostics_statement(p ExternallyInvokedProcedure) !ModuleStatement {
	mut sections := []string{}
	mut used := []string{}
	mut c := ''
	mut n := '0'
	mut kind := 'statement information'

	// - GR 3. The condition number must be the number of a condition in the
	// diagnostics area: invalid condition number.
	if t.accept('CONDITION') {
		c += '  long long vsql_m_n = ${t.condition_number(p, mut used)!};\n'
		c += '  if (vsql_m_n < 1 || vsql_m_n > vsql_m_da.number) {\n    vsql_m_sqlstate(SQLSTATE, "35000");\n    return;\n  }\n'
		n = 'vsql_m_n'
		kind = 'condition information'
	}
	items := if n == '0' { statement_information_items } else { condition_information_items }

	mut put := false
	for {
		if !t.accept(':') {
			return sqlstate_42601('procedure ${p.name}: expected a host parameter${t.near()}')
		}
		target := p.reference(t.c_name('host parameter name')!)!
		t.expect('=')!
		name := t.next_word()
		if name == 'ALL' {
			return sqlstate_42601('procedure ${p.name}: GET DIAGNOSTICS ... = ALL is not supported')
		}
		id := items[name] or {
			t.pos--
			return sqlstate_42601('procedure ${p.name}: expected a ${kind} item name${t.near()}')
		}
		used << target.name.to_upper()

		// - SR 1. The value is assigned to the target (9.1 Retrieval
		// assignment), so they must both be numbers or strings.
		typ := target.typ or { HostParameterType{} }
		if name in exact_numeric_diagnostics_items {
			if !typ.is_exact_numeric() {
				return sqlstate_42601('procedure ${p.name}: host parameter :${target.name} must be SMALLINT, INTEGER or BIGINT for ${name}')
			}
			value := if name == 'CONDITION_NUMBER' {
				'vsql_m_n'
			} else if id == '' {
				'0'
			} else {
				if 'diagnostics_number' !in sections {
					sections << 'diagnostics_number'
				}
				'vsql_m_item_number(${id}, ${n})'
			}
			c += '  *${target.name} = (${typ.c_type()})${value};\n'
		} else {
			if !typ.is_string() {
				return sqlstate_42601('procedure ${p.name}: host parameter :${target.name} must be CHARACTER or CHARACTER VARYING for ${name}')
			}
			value := if id == '' {
				'""'
			} else {
				if 'diagnostics_text' !in sections {
					sections << 'diagnostics_text'
				}
				'vsql_m_item_text(${id}, ${n})'
			}
			pad := if typ.typ == .is_character { 1 } else { 0 }
			c += '  vsql_m_w |= vsql_m_put(${target.name}, ${typ.length + 1}, ${pad}, ${value});\n'
			put = true
		}

		if !t.accept(',') {
			break
		}
	}

	if t.pos < t.tokens.len {
		return sqlstate_42601('procedure ${p.name}: unexpected${t.near()}')
	}

	if put {
		sections << 'diagnostics_put'
		c = '  int vsql_m_w = 0;\n${c}  vsql_m_sqlstate(SQLSTATE, vsql_m_w ? "01004" : "00000");\n'
	} else {
		c += '  vsql_m_sqlstate(SQLSTATE, "00000");\n'
	}

	return ModuleStatement{sections, used, c}
}

// condition_number reads a <condition number>, which is an unsigned integer or
// a host parameter that is exact numeric (Syntax Rule 3).
fn (mut t ModuleTokens) condition_number(p ExternallyInvokedProcedure, mut used []string) !string {
	return t.exact_numeric_value(p, mut used, 'condition number', false)
}

// exact_numeric_value reads a <simple value specification> that is exact
// numeric with scale 0 (zero), which is an integer (that can be negative if
// signed is true) or a host parameter that is exact numeric. It returns the C
// value, as a long long.
fn (mut t ModuleTokens) exact_numeric_value(p ExternallyInvokedProcedure, mut used []string, what string, signed bool) !string {
	sign := if signed && t.accept('-') { '-' } else { '' }
	if tok := t.peek() {
		if tok.kind == .number {
			t.pos++
			return '${sign}${tok.text.i64()}LL'
		}
	}

	if sign == '' && t.accept(':') {
		parameter := p.reference(t.c_name('host parameter name')!)!
		typ := parameter.typ or { HostParameterType{} }
		if !typ.is_exact_numeric() {
			return sqlstate_42601('procedure ${p.name}: the ${what} :${parameter.name} must be SMALLINT, INTEGER or BIGINT')
		}
		used << parameter.name.to_upper()

		return '(long long)*${parameter.name}'
	}

	return sqlstate_42601('procedure ${p.name}: expected a ${what}${t.near()}')
}
