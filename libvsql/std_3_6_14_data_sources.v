module main

// ISO/IEC 9075-3:2003(E), 6.14, DataSources
//
// Get server name(s) that the SQL/CLI application can connect to, along with
// description information, if available.
//
// A ServerName is the path of a database file, so there isn't a list of them.
// The data sources are the special ServerNames: ":memory:" and the DEFAULT
// server (an empty ServerName).

const data_sources = [
	['DEFAULT', 'A new in-memory database (the default connection)'],
	[':memory:', 'A new in-memory database'],
]

@[export: 'SQLDataSources']
fn sql_data_sources(environment_handle SQLInteger, direction i16, server_name &char, buffer_length1 i16, name_length1 &i16, description &char, buffer_length2 i16, name_length2 &i16) i16 {
	entry := enter(sql_handle_env, i64(environment_handle))
	defer {
		entry.leave()
	}
	// ISO/IEC 9075-3:2003(E), 6.14, DataSources, General Rules, 1-3. vsql
	// never has a skeleton SQL-environment.
	mut env := envs[i64(environment_handle)] or { return sql_invalid_handle }
	env.diag.clear()

	return data_sources_routine(mut env, direction, server_name, buffer_length1, name_length1,
		description, buffer_length2, name_length2) or { env.diag.error(err) }
}

fn data_sources_routine(mut env Env, direction i16, server_name &char, buffer_length1 i16, name_length1 &i16, description &char, buffer_length2 i16, name_length2 &i16) !i16 {
	// ISO/IEC 9075-3:2003(E), 6.14, DataSources, General Rules, 5 and 6: the
	// direction must be NEXT or FIRST.
	if direction !in [sql_fetch_next, sql_fetch_first] {
		return cli_error('HY103', 'invalid retrieval code')
	}

	// ISO/IEC 9075-3:2003(E), 6.14, DataSources, General Rules, 7-9: the data
	// sources (data_sources) are returned in order. FIRST (or after the last
	// one) starts again from the first data source.
	i := if direction == sql_fetch_first { 0 } else { env.data_source }
	if i >= data_sources.len {
		env.data_source = 0
		return no_data()
	}

	// ISO/IEC 9075-3:2003(E), 4.4.3, Null pointers
	if server_name == unsafe { nil } || description == unsafe { nil } {
		return cli_error('HY009', 'invalid use of null pointer')
	}

	nts := env.null_termination
	retrieve_string(mut env.diag, nts, server_name, data_sources[i][0], buffer_length1,
		name_length1, 2)!
	retrieve_string(mut env.diag, nts, description, data_sources[i][1], buffer_length2,
		name_length2, 2)!
	env.data_source = i + 1

	return env.diag.result()
}
