module vsql

// server_test.v tests the PostgreSQL server (see server.v) through its V API.

import net
import os
import time

// Without a connect function every client opens db_file. A SELECT without a
// FROM is allowed with select_without_from.
fn test_server_db_file() ! {
	// test_all has already removed sql_test_dir(), so this has its own.
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-server-db-file-${os.getpid()}')
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}

	mut server := start_sql_test_server_with(ServerOptions{
		db_file:             os.join_path(dir, 'test.vsql')
		select_without_from: true
	})!
	defer {
		server.stop() or {}
	}

	mut client1 := new_pg_test_client(server.port()!, 'ignored')!
	defer {
		client1.close()
	}
	assert client1.query('SELECT 1 AS x')!.rows == ['X: 1']
	client1.query('CREATE TABLE t (x INT)')!
	client1.query('INSERT INTO t (x) VALUES (123)')!

	mut client2 := new_pg_test_client(server.port()!, 'ignored')!
	defer {
		client2.close()
	}
	assert client2.query('SELECT * FROM t')!.rows == ['X: 123']
}

// A client that waits between statements isn't disconnected.
fn test_server_idle_client() ! {
	mut server := new_server(ServerOptions{
		connect: fn (database string) !&Connection {
			return open(':memory:')
		}
	})
	server.listen()!
	defer {
		server.stop() or {}
	}
	mut client := net.dial_tcp('127.0.0.1:${server.port()!}')!
	defer {
		client.close() or {}
	}
	mut conn := server.accept()!
	defer {
		conn.close() or {}
	}
	assert conn.read_timeout() == net.infinite_timeout
}

// A client only gets an error (or is disconnected) when its database can't be
// opened, it disconnects before sending its startup message or it disconnects
// without saying goodbye. The server keeps running for other clients.
fn test_server_host() ! {
	connect := fn (database string) !&Connection {
		return open(':memory:')
	}

	// Only clients on the same machine can connect by default.
	mut local := new_server(ServerOptions{
		connect: connect
	})
	if _ := local.address() {
		assert false, 'has an address before listening'
	} else {
		assert err.msg() == 'server is not listening'
	}
	local.listen()!
	defer {
		local.stop() or {}
	}
	assert local.address()! == '127.0.0.1:${local.port()!}'

	mut ip6 := new_server(ServerOptions{
		connect: connect
		host:    '::1'
	})
	ip6.listen()!
	defer {
		ip6.stop() or {}
	}
	assert ip6.address()! == '[::1]:${ip6.port()!}'

	// 192.0.2.1 is reserved for documentation, so it can't be a local address.
	mut remote := new_server(ServerOptions{
		connect: connect
		host:    '192.0.2.1'
	})
	if _ := remote.listen() {
		assert false, 'listened on an address that is not local'
	} else {
		assert err.msg().starts_with('cannot listen on 192.0.2.1:0: ')
	}
}

// A query without a statement has an empty response from the server, even if
// the option could change it into a statement. It's an error for the library,
// see tests/std_2_5_2_bracketed_comments.sql. A query that can't be tokenized
// isn't empty.
fn test_server_empty_query() ! {
	mut server := start_sql_test_server_with(ServerOptions{
		select_without_from: true
		connect:             fn (database string) !&Connection {
			return open(':memory:')
		}
	})!
	defer {
		server.stop() or {}
	}
	mut client := new_pg_test_client(server.port()!, 'db')!

	for query in ['', ' ', ';', ' ; ; ', '/* x */;', '/* SELECT */', '-- x'] {
		output := client.query(query)!
		assert output.error == '', query
		assert output.msg == '', query
		assert output.rows.len == 0, query
	}

	assert client.query('/* x')!.error != ''
	assert client.query('EXPLAIN /* x */;')!.error == 'error 42601: syntax error: unexpected \$end'
	assert client.query('VALUES 1;')!.rows == ['COL1: 1']
}

// A client that disconnects in the middle of a transaction is rolled back. If
// the rollback fails, the server only logs it.
fn test_server_disconnect_rollback_fails() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-sql-test-server-rollback-${os.getpid()}')
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}

	mut server := start_sql_test_server_with(ServerOptions{
		db_file: os.join_path(dir, 'test.vsql')
	})!
	defer {
		server.stop() or {}
	}

	mut client := new_pg_test_client(server.port()!, 'db')!
	client.query('CREATE TABLE t (x INT)')!
	client.query('START TRANSACTION')!
	client.query('INSERT INTO t (x) VALUES (1)')!

	// The rollback locks the file, which fails once the client has gone.
	arm_fault('lock', 1)!
	defer {
		disarm_faults()
	}
	client.close()
	mut faults := unsafe { &FaultPoints(fault_points) }
	for _ in 0 .. 500 {
		if 'lock' !in faults.armed {
			break
		}
		time.sleep(10 * time.millisecond)
	}
	assert 'lock' !in faults.armed
}

fn test_server_client_errors() ! {
	mut server := start_sql_test_server_with(ServerOptions{
		connect: fn (database string) !&Connection {
			if database == 'missing' {
				return error('no such database: ${database}')
			}

			return open(':memory:')
		}
	})!
	defer {
		server.stop() or {}
	}
	port := server.port()!

	if _ := new_pg_test_client(port, 'missing') {
		assert false, 'connected to a missing database'
	} else {
		assert err.msg() == 'no such database: missing'
	}

	mut early := net.dial_tcp('127.0.0.1:${port}')!
	early.close()!

	mut abrupt := new_pg_test_client(port, 'db')!
	abrupt.conn.close()!

	// The server keeps accepting clients after it fails to accept one.
	arm_fault('accept', 1)!
	defer {
		disarm_faults()
	}
	if _ := new_pg_test_client(port, 'db') {
		assert false, 'connected while accept is failing'
	}

	mut client := new_pg_test_client(port, 'db')!
	defer {
		client.close()
	}
	assert client.query('VALUES 1')!.rows == ['COL1: 1']
}

// verbose prints every message in and out of the server.
fn test_server_verbose() ! {
	// stdout can't be captured the same way on Windows, so the messages are
	// only printed there.
	$if windows {
		mut server := start_sql_test_server_with(ServerOptions{
			connect: fn (database string) !&Connection {
				return open(':memory:')
			}
			verbose: true
		})!
		defer {
			server.stop() or {}
		}
		mut client := new_pg_test_client(server.port()!, 'db')!
		assert client.query('VALUES 1')!.rows == ['COL1: 1']
		client.close()
		return
	}

	stdout_path := os.join_path(os.temp_dir(), 'vsql-sql-test-stdout-${os.getpid()}.txt')
	stdout_file := os.create(stdout_path)!
	saved_stdout := C.dup(1)
	C.dup2(stdout_file.fd, 1)
	defer {
		C.dup2(saved_stdout, 1)
		os.rm(stdout_path) or {}
	}

	mut server := start_sql_test_server_with(ServerOptions{
		connect: fn (database string) !&Connection {
			return open(':memory:')
		}
		verbose: true
	})!
	defer {
		server.stop() or {}
	}

	mut client := new_pg_test_client(server.port()!, 'db')!
	assert client.query('VALUES 1')!.rows == ['COL1: 1']
	client.close()

	// The server logs the disconnect after the client has gone. The message and
	// its newline may be written separately, so it waits for the whole line.
	mut stdout := ''
	for _ in 0 .. 500 {
		stdout = os.read_file(stdout_path)!
		if stdout.contains('disconnected\n') {
			break
		}
		time.sleep(10 * time.millisecond)
	}

	lines := stdout.split('\n')
	assert 'connected' in lines
	assert 'query: VALUES 1' in lines
	assert 'disconnected' in lines
}

// A client of a new server must not be accepted by a server that was stopped,
// which is about to wait for a client when it's stopped. The file descriptor of
// the old listener is reused by the new one.
fn test_server_stop_then_listen() ! {
	for _ in 0 .. 200 {
		mut old := start_sql_test_server_with(ServerOptions{
			connect: fn (database string) !&Connection {
				return error('connected to the old server')
			}
		})!
		mut early := net.dial_tcp('127.0.0.1:${old.port()!}')!
		early.close()!
		old.stop()!

		mut new := start_sql_test_server_with(ServerOptions{
			connect: fn (database string) !&Connection {
				return open(':memory:')
			}
		})!
		mut client := new_pg_test_client(new.port()!, 'db')!
		assert client.query('VALUES 1')!.rows == ['COL1: 1']
		client.close()
		new.stop()!
	}

	// A server is stopped before it listens, or before it gets to serve.
	mut unserved := new_server(ServerOptions{
		connect: fn (database string) !&Connection {
			return open(':memory:')
		}
	})
	unserved.stop()!
	unserved = new_server(ServerOptions{
		connect: fn (database string) !&Connection {
			return open(':memory:')
		}
	})
	unserved.listen()!
	unserved.stop()!
	unserved.serve()!

	// A server on every interface is woken up on its loopback address.
	for host in ['0.0.0.0', '::'] {
		mut every := start_sql_test_server_with(ServerOptions{
			host:    host
			connect: fn (database string) !&Connection {
				return open(':memory:')
			}
		})!
		time.sleep(10 * time.millisecond)
		every.stop()!
	}
}

// A PostgreSQL SET of a run-time parameter is ignored with ignore_pg_set, but a
// SET in the SQL standard still runs.
fn test_server_ignore_pg_set() ! {
	connect := fn (database string) !&Connection {
		return open(':memory:')
	}
	mut server := start_sql_test_server_with(ServerOptions{
		ignore_pg_set: true
		connect:       connect
	})!
	defer {
		server.stop() or {}
	}
	mut client := new_pg_test_client(server.port()!, 'db')!
	defer {
		client.close()
	}

	for query in ['SET LOCAL search_path TO public', 'SET SESSION datestyle = ISO',
		"set application_name = 'x';"] {
		output := client.query(query)!
		assert output.error == '', query
		assert output.msg == 'SET', query
	}
	assert client.query("SET SCHEMA 'NOPE'")!.error.starts_with('error 3F000: ')
	assert client.query('SET search_path')!.error.starts_with('error 42601: ')

	// Anything else still runs.
	assert client.query('VALUES 1')!.error == ''

	// Without the option it's a syntax error.
	mut plain := start_sql_test_server_with(ServerOptions{
		connect: connect
	})!
	defer {
		plain.stop() or {}
	}
	mut plain_client := new_pg_test_client(plain.port()!, 'db')!
	defer {
		plain_client.close()
	}
	assert plain_client.query('SET LOCAL search_path TO public')!.error.starts_with('error 42601: ')
}

// rewrite_pg_syntax changes PostgreSQL casts into a CAST and removes
// "pg_catalog." before a name, but not in quotes or comments.
fn test_rewrite_pg_syntax() {
	for query, expected in {
		'SELECT reltuples::int8 FROM pg_class':                       'SELECT CAST(reltuples AS BIGINT) FROM pg_class'
		'SELECT c.x :: pg_catalog.int2, 1::int, 2::int4, 3::oid':     'SELECT CAST(c.x AS SMALLINT), CAST(1 AS INTEGER), CAST(2 AS INTEGER), CAST(3 AS INTEGER)'
		'VALUES 1.5::float4 + 2::float8, true::bool':                 'VALUES CAST(1.5 AS REAL) + CAST(2 AS DOUBLE PRECISION), CAST(true AS BOOLEAN)'
		"VALUES 'it''s'::text, 'x'::name, (1 + (2))::numeric":        "VALUES CAST('it''s' AS VARCHAR(255)), CAST('x' AS VARCHAR(255)), CAST((1 + (2)) AS NUMERIC)"
		"VALUES count(*)::regclass, 'a'::regproc, 'b'::regnamespace": "VALUES CAST(count(*) AS VARCHAR(255)), CAST('a' AS VARCHAR(255)), CAST('b' AS VARCHAR(255))"
		"x = 'pg_catalog.trigger'::pg_catalog.regtype":               "x = CAST('pg_catalog.trigger' AS VARCHAR(255))"
		'SELECT "a::b"::int8, "x""y"::int8 FROM PG_CATALOG.pg_class': 'SELECT CAST("a::b" AS BIGINT), CAST("x""y" AS BIGINT) FROM pg_class'
		'SELECT pg_catalog.f(x), my_pg_catalog.t, "pg_catalog.x"':    'SELECT f(x), my_pg_catalog.t, "pg_catalog.x"'
		"SELECT 'unterminated::int":                                  "SELECT 'unterminated::int"
		'SELECT 1 -- pg_catalog.x::int\nFROM pg_catalog.t':           'SELECT 1 -- pg_catalog.x::int\nFROM t'
		'SELECT 1 -- x::int':                                         'SELECT 1 -- x::int'
		'SELECT /* pg_catalog.x::int */ 1::int8':                     'SELECT /* pg_catalog.x::int */ CAST(1 AS BIGINT)'
		'SELECT /* x::int':                                           'SELECT /* x::int'
		'SELECT NULL AS a, 1, null as b UNION SELECT 1,NULL\tAS c':   'SELECT CAST(NULL AS BIGINT) AS a, 1, CAST(NULL AS BIGINT) as b UNION SELECT 1,CAST(NULL AS BIGINT)\tAS c'
		'SELECT x IS NULL AS a, NULLS AS b, NULL ASC, NULL AS':       'SELECT x IS NULL AS a, NULLS AS b, NULL ASC, CAST(NULL AS BIGINT) AS'
		'NULL AS a, NULL':                                            'NULL AS a, NULL'
		'XSELECT NULL AS a':                                          'XSELECT NULL AS a'
		'::int':                                                      'CAST( AS INTEGER)'
	} {
		assert rewrite_pg_syntax(query) == expected, query
	}
}

// With rewrite_pg_syntax, the server rewrites a query before it's run.
fn test_server_rewrite_pg_syntax() ! {
	connect := fn (database string) !&Connection {
		return open(':memory:')
	}
	mut server := start_sql_test_server_with(ServerOptions{
		rewrite_pg_syntax: true
		connect:           connect
	})!
	defer {
		server.stop() or {}
	}
	mut client := new_pg_test_client(server.port()!, 'db')!
	defer {
		client.close()
	}
	assert client.query("SELECT pg_catalog.pg_get_userbyid(10) AS owner, reltuples::int8 AS n FROM pg_catalog.pg_class WHERE relname = 'X'")!.rows == []
	assert client.query('VALUES 1.5::float8')!.rows == ['COL1: 1.5e0']
	assert client.query('SELECT NULL AS x FROM pg_database UNION SELECT 1 FROM pg_database')!.rows == [
		'X: NULL',
		'X: 1',
	]

	// Without the option it's an error.
	mut plain := start_sql_test_server_with(ServerOptions{
		connect: connect
	})!
	defer {
		plain.stop() or {}
	}
	mut plain_client := new_pg_test_client(plain.port()!, 'db')!
	defer {
		plain_client.close()
	}
	assert plain_client.query('VALUES 1::int8')!.error != ''
}

// With lower_case_names, a column name without lower case letters is sent in
// lower case, like a name that isn't quoted in PostgreSQL.
fn test_server_lower_case_names() ! {
	mut server := start_sql_test_server_with(ServerOptions{
		lower_case_names: true
		connect:          fn (database string) !&Connection {
			return open(':memory:')
		}
	})!
	defer {
		server.stop() or {}
	}
	mut client := new_pg_test_client(server.port()!, 'db')!
	defer {
		client.close()
	}
	assert client.query('SELECT * FROM (VALUES ROW(1, 2, 3)) AS t (a, "Bc", "d e")')!.rows == [
		'a: 1 Bc: 2 d e: 3',
	]
}

// The functions and tables of PostgreSQL clients are only registered for the
// clients of the server, not for any other connection.
fn test_pg_objects_only_for_server() ! {
	mut db := open(':memory:')!
	defer {
		db.close()
	}
	if _ := db.query('SELECT * FROM pg_class') {
		assert false, 'pg_class is registered'
	} else {
		assert err is SQLState42P01
	}
	if _ := db.query('VALUES version()') {
		assert false, 'version() is registered'
	} else {
		assert err is SQLState42883
	}

	mut server := start_sql_test_server_with(ServerOptions{
		connect: fn (database string) !&Connection {
			return open(':memory:')
		}
	})!
	defer {
		server.stop() or {}
	}
	mut client := new_pg_test_client(server.port()!, 'db')!
	defer {
		client.close()
	}
	assert client.query('SELECT COUNT(*) FROM pg_class')!.rows.len == 1
	assert client.query('VALUES version()')!.rows.len == 1
}
