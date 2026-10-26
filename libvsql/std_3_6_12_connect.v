module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.12, Connect
//
// Establish a connection.
//
// The ServerName is the path of the database file, or ":memory:". The DEFAULT
// server (when ServerName is empty) is a new in-memory database. UserName and
// Authentication are not used.

@[export: 'SQLConnect']
fn sql_connect(connection_handle SQLInteger, server_name &char, name_length1 i16, user_name &char, name_length2 i16, authentication &char, name_length3 i16) i16 {
	mut dbc := dbcs[i64(connection_handle)] or { return sql_invalid_handle }
	dbc.diag.clear()

	return connect(mut dbc, server_name, name_length1, user_name, name_length2, authentication,
		name_length3) or { dbc.diag.error(err) }
}

fn connect(mut dbc Dbc, server_name &char, name_length1 i16, user_name &char, name_length2 i16, authentication &char, name_length3 i16) !i16 {
	// - 3. If there is an established SQL-connection associated with C, then an
	// exception condition is raised: connection exception — connection name in
	// use.
	if dbc.conn != none {
		return cli_error('08002', 'connection name in use')
	}

	// - 4, 5, 6. ServerName may be a null pointer, and its length can't be more
	// than 128 octets.
	sn := input_string(server_name, name_length1)!
	if sn.len > 128 {
		return cli_error('HY090', 'invalid string length or buffer length')
	}
	dbc.server_name = if sn == '' { 'DEFAULT' } else { sn }

	// - 8, 9, 10, 11. UserName and Authentication may also be null pointers.
	un := input_string(user_name, name_length2)!
	au := input_string(authentication, name_length3)!

	path := if sn == '' {
		// - 12.a. If the value of SN is 'DEFAULT', then the user name and
		// authentication must not be given, and there can only be one default
		// connection in the SQL-environment.
		if un != '' || au != '' {
			return cli_error('HY090', 'invalid string length or buffer length')
		}
		for _, other in dbcs {
			if other.env == dbc.env && other.is_default && other.conn != none {
				return cli_error('08002', 'connection name in use')
			}
		}
		':memory:'
	} else {
		sn
	}

	dbc.conn = vsql.open(path) or {
		return cli_error('08001', 'SQL-client unable to establish SQL-connection: ${err.msg()}')
	}
	dbc.is_default = sn == ''

	return sql_success
}
