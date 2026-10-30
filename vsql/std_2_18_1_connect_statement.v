module vsql

import time

// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>
//
// Establish an SQL-session.
//
// The <SQL-server name> is the path of a database file, or ":memory:". DEFAULT
// is the default SQL-server of the Agent. The <connection user name> is checked,
// but not used, so there isn't an implicit one.
//
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, Syntax Rules, 1
// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 8.a and 8.b
//
// The concepts are described by:
//
// ISO/IEC 9075-2:2016(E), 4.42, SQL-connections
// ISO/IEC 9075-2:2016(E), 4.43, SQL-sessions

struct ConnectStatement {
	// target is none for DEFAULT.
	target ?ConnectionTarget
}

struct ConnectionTarget {
	server_name          ValueSpecification
	connection_name      ?ValueSpecification
	connection_user_name ?ValueSpecification
}

fn (stmt ConnectStatement) execute(mut a Agent, elapsed_parse time.Duration) !Result {
	t := start_timer()

	// Each SQL-connection is to a different SQL-server, and vsql doesn't
	// support transactions that affect more than one SQL-server.
	//
	// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 1
	a.check_multiple_server_transactions()!

	target := stmt.target or {
		// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 7 and 8.a
		if a.default_connection != unsafe { nil } {
			return sqlstate_08002('DEFAULT')
		}
		a.default_connection = a.open_default() or { return sqlstate_08001(err.msg()) }
		a.current = a.default_connection

		return new_result_msg('CONNECT', elapsed_parse, t.elapsed())
	}

	// There aren't any other restrictions on the user name.
	//
	// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 2 to 5
	if user_name := target.connection_user_name {
		v := connection_string(user_name)!.trim(' ')
		normalize_identifier(v) or { return sqlstate_28000(v) }
	}

	// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 6 and 7
	cn := connection_name(target.connection_name or { target.server_name })!
	if cn in a.connections {
		return sqlstate_08002(cn)
	}

	// If it fails, the current SQL-connection doesn't change (NOTE 719).
	//
	// ISO/IEC 9075-2:2016(E), 18.1, <connect statement>, General Rules, 8.b, 9.b and 10
	conn := open(connection_string(target.server_name)!) or { return sqlstate_08001(err.msg()) }
	a.connections[cn] = conn
	a.current = conn

	return new_result_msg('CONNECT', elapsed_parse, t.elapsed())
}

// connection_string is the value of a <simple value specification> in a
// connection statement, which can only be a literal in direct SQL.
//
// The value isn't checked to be a character string of at most 128 octets
// (ISO/IEC 9075-2:2016(E), 5.4, Names and identifiers, Syntax Rules, 23), so
// an <SQL-server name> can be a longer path.
fn connection_string(spec ValueSpecification) !string {
	if spec is Value {
		return spec.str()
	}

	// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>, Syntax Rules, 1
	return sqlstate_42601('a direct SQL statement cannot contain a parameter')
}

// connection_name is the name of an SQL-connection, the same as an identifier,
// with leading and trailing spaces removed (ISO/IEC 9075-2:2016(E), 4.42).
fn connection_name(spec ValueSpecification) !string {
	cn := connection_string(spec)!.trim(' ')

	return normalize_identifier(cn) or { return sqlstate_2e000(cn) }
}

// normalize_identifier returns the name of an <identifier>, which is upper case
// for a regular identifier. An error is returned if s isn't one identifier.
fn normalize_identifier(s string) !string {
	tokens := tokenize(s)!
	if tokens.len != 1 || s.contains(';') {
		return error('not an identifier')
	}

	sym := tokens[0].sym.v
	if sym is IdentifierChain {
		if sym.identifier.starts_with('"') {
			return sym.identifier[1..sym.identifier.len - 1].replace('""', '"')
		}

		return sym.identifier.to_upper()
	}

	// A key word.
	if sym is string && sym.len > 0 && sym[0].is_letter() {
		return sym
	}

	return error('not an identifier')
}
