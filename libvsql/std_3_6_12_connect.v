module main

import vsql

// ISO/IEC 9075-3:2003(E), 6.12, Connect
//
// Establish a connection.
//
// The ServerName is the path of the database file, or ":memory:". The DEFAULT
// server (when ServerName is empty or "DEFAULT") is a new in-memory database.
// UserName and Authentication are not used.

@[export: 'SQLConnect']
fn sql_connect(connection_handle SQLInteger, server_name &char, name_length1 i16, user_name &char, name_length2 i16, authentication &char, name_length3 i16) i16 {
	h := i64(connection_handle)
	mut dbc := dbcs[h] or { return sql_invalid_handle }
	dbc.diag.clear()

	return connect(mut dbc, h, server_name, name_length1, user_name, name_length2, authentication,
		name_length3) or { dbc.diag.error(err) }
}

fn connect(mut dbc Dbc, h i64, server_name &char, name_length1 i16, user_name &char, name_length2 i16, authentication &char, name_length3 i16) !i16 {
	// - 2. If an SQL-transaction is active for the current SQL-connection and
	// the implementation does not support transactions that affect more than
	// one SQL-server, then an exception condition is raised: feature not
	// supported — multiple server transactions.
	if current_connection != 0 && transaction_active(sql_handle_dbc, current_connection) {
		return cli_error('0A001', 'multiple server transactions')
	}

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
	// - 5.a. If L1 is zero, then let 'DEFAULT' be the value of SN.
	dbc.server_name = if sn == '' { 'DEFAULT' } else { sn }
	is_default := dbc.server_name == 'DEFAULT'

	// - 8, 9, 10, 11. UserName and Authentication may also be null pointers.
	un := input_string(user_name, name_length2)!
	au := input_string(authentication, name_length3)!

	path := if is_default {
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
	dbc.is_default = is_default

	// - 14. The current SQL-connection becomes dormant, and the new one becomes
	// the current SQL-connection.
	current_connection = h

	return sql_success
}
