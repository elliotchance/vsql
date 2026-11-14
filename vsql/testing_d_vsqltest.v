module vsql

// testing_d_vsqltest.v has the helpers that are shared by the SQL tests
// (sql_test.v) and the V tests in the other *_test.v files. V compiles each
// *_test.v file on its own, so they can't share code with each other. This file
// is only compiled with "-d vsqltest" (see the Makefile), so it isn't part of
// the module otherwise, and it's left out of the coverage.

import encoding.binary
import net
import os
import time

// sql_test_dir holds the database files of the tests that are running.
fn sql_test_dir() string {
	return os.join_path(os.temp_dir(), 'vsql-sql-test-${os.getpid()}')
}

// sql_test_options are the connection options for every test. Small pages make
// even small tests split pages and store large values across several pages. A
// test runs its connections one statement at a time, so CREATE INDEX can't wait
// for another connection. A small page cache means pages are often removed from
// it and read again.
fn sql_test_options() ConnectionOptions {
	mut options := default_connection_options()
	options.page_size = 256
	options.create_index_timeout = 0
	options.cache_size = 4

	// The statements of a test run one after another, so a transaction that
	// waits for another connection would always time out.
	options.lock_timeout = 0

	return options
}

// sql_test_now is the time for every test. 09:05:03 UTC is 14:05:03 local time
// at +05:00.
fn sql_test_now() (time.Time, i16) {
	return time.new(time.Time{
		year:       2022
		month:      7
		day:        4
		hour:       9
		minute:     5
		second:     3
		nanosecond: 120056000
	}), 300
}

// SQLTestTickingClock is the clock for "clock tick", which is a second later
// each time it's read.
struct SQLTestTickingClock {
mut:
	ticks int
}

fn (mut c SQLTestTickingClock) now() (time.Time, i16) {
	now, offset := sql_test_now()
	c.ticks++

	return now.add_seconds(c.ticks - 1), offset
}

// SQLTestOutput is what a statement returned, in the format of the expected
// output of a test.
struct SQLTestOutput {
mut:
	// error is set (and nothing else) if the statement failed.
	error string
	// flags are the features of the statement, for the "flags" directive.
	flags    string
	warnings []string
	msg      string
	rows     []string
}

// PGTestClient is a minimal PostgreSQL client for running the tests through the
// server. It only knows the simple query protocol.
struct PGTestClient {
mut:
	conn &net.TcpConn
}

fn new_pg_test_client(port int, database string) !&PGTestClient {
	mut client := &PGTestClient{net.dial_tcp('127.0.0.1:${port}')!}

	// A statement can take longer than V's default of 30 seconds on a slow
	// machine.
	client.conn.set_read_timeout(10 * time.minute)

	// StartupMessage: protocol 3.0, then name/value pairs.
	mut body := []u8{}
	body << pg_test_int32(196608)
	for s in ['user', 'vsql', 'database', database] {
		body << s.bytes()
		body << 0
	}
	body << 0
	mut startup := pg_test_int32(body.len + 4)
	startup << body
	client.conn.write(startup)!

	// AuthenticationOk, then ReadyForQuery. An error means the database couldn't
	// be opened.
	for {
		msg_type, msg := client.read_message()!
		match msg_type {
			`E` { return error(pg_test_fields(msg)['M']) }
			`Z` { break }
			else {}
		}
	}

	return client
}

fn (mut c PGTestClient) query(stmt string) !SQLTestOutput {
	mut query := [u8(`Q`)]
	query << pg_test_int32(stmt.len + 5)
	query << stmt.bytes()
	query << 0
	c.conn.write(query)!

	mut output := SQLTestOutput{}
	mut columns := []string{}
	for {
		msg_type, msg := c.read_message()!
		match msg_type {
			// RowDescription: the name of each column, followed by 18 bytes that
			// aren't needed.
			`T` {
				columns = []
				mut at := 2
				for _ in 0 .. pg_test_read_int16(msg, 0) {
					end := pg_test_string_end(msg, at)
					columns << msg[at..end].bytestr()
					at = end + 1 + 18
				}
			}
			// DataRow: the length and text of each value.
			`D` {
				mut line := ''
				mut at := 2
				for column in columns {
					len := pg_test_read_int32(msg, at)
					at += 4
					line += '${column}: ${msg[at..at + len].bytestr()} '
					at += len
				}
				output.rows << line.trim_space()
			}
			// CommandComplete: a query only has a tag for the number of rows. An
			// INSERT tag also has an OID, like "INSERT 0 3".
			`C` {
				tag := msg[..msg.len - 1].bytestr()
				if columns.len == 0 {
					output.msg = if tag.starts_with('INSERT 0 ') {
						'INSERT ${tag[9..]}'
					} else {
						tag
					}
				}
			}
			// EmptyQueryResponse: there's no result, see test_server_empty_query.
			`I` {}
			// The server sends XX000 (internal_error) for an error that isn't a
			// SQLSTATE, which the library reports as 00000.
			`E`, `N` {
				fields := pg_test_fields(msg)
				code := if fields['C'] == 'XX000' { '00000' } else { fields['C'] }
				if msg_type == `E` {
					output.error = 'error ${code}: ${fields['M']}'
				} else {
					output.warnings << 'warning ${code}: ${fields['M']}'
				}
			}
			`Z` {
				break
			}
			else {
				return error('unexpected message: ${msg_type.ascii_str()}')
			}
		}
	}

	return output
}

fn (mut c PGTestClient) close() {
	c.conn.write([u8(`X`), 0, 0, 0, 4]) or {}
	c.conn.close() or {}
}

// read_message returns the type and body of the next message.
fn (mut c PGTestClient) read_message() !(u8, []u8) {
	header := c.read_exactly(5)!
	body := c.read_exactly(pg_test_read_int32(header, 1) - 4)!

	return header[0], body
}

fn (mut c PGTestClient) read_exactly(n int) ![]u8 {
	mut buf := []u8{len: n}
	mut read := 0
	for read < n {
		read += c.conn.read(mut buf[read..])!
	}

	return buf
}

// pg_test_fields returns the fields of an ErrorResponse or NoticeResponse.
fn pg_test_fields(msg []u8) map[string]string {
	mut fields := map[string]string{}
	mut at := 0
	for at < msg.len && msg[at] != 0 {
		end := pg_test_string_end(msg, at + 1)
		fields[msg[at].ascii_str()] = msg[at + 1..end].bytestr()
		at = end + 1
	}

	return fields
}

// pg_test_string_end is the position of the zero byte that ends the string
// starting at at.
fn pg_test_string_end(b []u8, at int) int {
	mut end := at
	for b[end] != 0 {
		end++
	}

	return end
}

fn pg_test_int32(x int) []u8 {
	mut b := []u8{len: 4}
	binary.big_endian_put_u32(mut b, u32(x))

	return b
}

fn pg_test_read_int32(b []u8, at int) int {
	return int(binary.big_endian_u32(b[at..at + 4]))
}

fn pg_test_read_int16(b []u8, at int) int {
	return int(binary.big_endian_u16(b[at..at + 2]))
}

// start_sql_test_server_with starts another server, see start_sql_test_server.
fn start_sql_test_server_with(options ServerOptions) !&Server {
	mut server := new_server(options)
	server.listen()!
	spawn fn (mut server Server) {
		server.serve() or { eprintln('server stopped: ${err}') }
	}(mut server)

	return server
}

// run_in_child runs the child function with the name (see child_function) in a
// child process, and returns its exit code and what it wrote to stderr. It's for
// code that stops the process, such as a panic, which can't be recovered from.
// The child's coverage is still counted, because it's written when the child
// exits.
//
// Windows has no fork, so there the child is this test program again, with
// VSQL_TEST_CHILD set to the name, which only runs that function (see
// testsuite_begin in storage_test.v). What the child writes to stdout is also in
// the result, since os.exec can't keep them apart, and the line endings are \r\n.
fn run_in_child(name string) !(int, string) {
	$if windows {
		os.setenv('VSQL_TEST_CHILD', name, true)
		result := os.exec([os.executable()])
		os.unsetenv('VSQL_TEST_CHILD')

		return result.exit_code, result.output.replace('\r\n', '\n')
	} $else {
		stderr_path := os.join_path(os.temp_dir(), 'vsql-sql-test-child-${os.getpid()}.txt')
		pid := os.fork()
		if pid == 0 {
			stderr_file := os.create(stderr_path) or { exit(100) }
			C.dup2(stderr_file.fd, 2)
			child_function(name)()
			exit(0)
		}

		mut status := 0
		C.waitpid(pid, &status, 0)
		stderr := os.read_file(stderr_path)!
		os.rm(stderr_path)!

		return (status >> 8) & 0xff, stderr
	}
}

// child_function is the code that run_in_child runs in a child process.
fn child_function(name string) fn () {
	return match name {
		'catalog' {
			fn () {
				mut db := open(':memory:') or { panic(err) }
				db.current_catalog = 'NOPE'
				_ := db.catalog()
			}
		}
		'catalog_for' {
			fn () {
				mut db := open(':memory:') or { panic(err) }
				_ := db.catalog_for(Identifier{ catalog_name: 'NOPE' })
			}
		}
		'yy_as' {
			fn () {
				_ := yy_as[string](YYSym(true))
			}
		}
		'yy_unbox' {
			fn () {
				_ := yy_unbox[Stmt](YYSym(yy_box(Table{})))
			}
		}
		'page_add' {
			fn () {
				mut page := new_page(kind_leaf, 64)
				page.add(new_page_object('k'.bytes(), 1, 0, []u8{len: 100})) or {}
			}
		}
		'crash_point' {
			fn () {
				mut state := unsafe { &CrashPoint(crash_point_state) }
				unsafe {
					*state = CrashPoint{
						at: 2
					}
				}
				crash_point()
				eprintln('first crash point passed')
				crash_point()
				eprintln('second crash point passed')
			}
		}
		else {
			panic('unknown child function: ${name}')
		}
	}
}

// A panic is for something that can't happen, so these break an invariant
// directly to check that it's caught, rather than carrying on with bad data.
//
// The exit code is 1, except that V's backtrace (after the message) can crash on
// Linux ARM64, which exits with 255 (https://github.com/vlang/v/issues/31422).
const panic_exit_codes = $if linux && arm64 { [1, 255] } $else { [1] }

const flagging_prepare = 'PROCEDURE s (SQLSTATE, :q CHAR(9)); PREPARE s FROM :q; '

const flagging_dynamic_cursor = flagging_prepare + 'DECLARE c CURSOR FOR s; '

// SQL-client modules. Every module needs its language (B112), which isn't listed
// in each row here.
const flagging_modules = {
	// A host parameter isn't a <dynamic parameter specification> (B031), and a
	// cursor doesn't need its vsql extensions in a module.
	'PROCEDURE p (SQLSTATE); COMMIT;':                                                                                                                                                                                                                                                  []string{}
	'PROCEDURE p (SQLSTATE, :x INT); DELETE FROM t WHERE x = :x;':                                                                                                                                                                                                                      []string{}
	'PROCEDURE p (SQLSTATE, :x INT); SELECT x INTO :x FROM t;':                                                                                                                                                                                                                         []string{}
	"PROCEDURE p (SQLSTATE); SET SCHEMA 'x';":                                                                                                                                                                                                                                          ['F761']
	'DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE o (SQLSTATE); OPEN c; PROCEDURE f (SQLSTATE, :x INT); FETCH c INTO :x; PROCEDURE d (SQLSTATE); DELETE FROM t WHERE CURRENT OF c; PROCEDURE u (SQLSTATE); UPDATE t SET x = 1 WHERE CURRENT OF c; PROCEDURE e (SQLSTATE); CLOSE c;': []string{}
	// The grammar and the lexer still find features, including of a host
	// parameter that isn't used.
	'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = CURRENT_SCHEMA;':                                                                                                                                                                                                                  ['F763']
	'PROCEDURE p (SQLSTATE, :x BIGINT); COMMIT;':                                                                                                                                                                                                                                       ['T071']
	"PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = 'a'\n'b';":                                                                                                                                                                                                                        ['F271']
	'DECLARE c CURSOR WITHOUT HOLD FOR SELECT x FROM t FETCH FIRST 1 ROW ONLY; PROCEDURE o (SQLSTATE); OPEN c;':                                                                                                                                                                        [
		'F857',
		'T551',
	]
	'DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE o (SQLSTATE); OPEN c; PROCEDURE f (SQLSTATE, :x INT); FETCH NEXT FROM c INTO :x;':                                                                                                                                                 ['F432']
	// Connection statements.
	'PROCEDURE p (SQLSTATE); CONNECT TO DEFAULT;':                                                                                                                                                                                                                                      ['F771']
	'PROCEDURE p (SQLSTATE); SET CONNECTION DEFAULT;':                                                                                                                                                                                                                                  ['F771']
	'PROCEDURE p (SQLSTATE); DISCONNECT ALL;':                                                                                                                                                                                                                                          ['F771']
	// A descriptor name that's an identifier also needs B035.
	'PROCEDURE p (SQLSTATE); ALLOCATE DESCRIPTOR d;':                                                                                                                                                                                                                                   [
		'B031',
		'B035',
	]
	'PROCEDURE p (SQLSTATE); ALLOCATE SQL DESCRIPTOR "d";':                                                                                                                                                                                                                             [
		'B031',
		'B035',
	]
	"PROCEDURE p (SQLSTATE); ALLOCATE DESCRIPTOR 'd' WITH MAX 5;":                                                                                                                                                                                                                      ['B031']
	"PROCEDURE p (SQLSTATE); ALLOCATE DESCRIPTOR GLOBAL 'd';":                                                                                                                                                                                                                          ['B031']
	"PROCEDURE p (SQLSTATE, :n INT); ALLOCATE DESCRIPTOR 'd' WITH MAX :n;":                                                                                                                                                                                                             [
		'B031',
		'B032',
	]
	"PROCEDURE p (SQLSTATE); DEALLOCATE DESCRIPTOR 'd';":                                                                                                                                                                                                                               ['B031']
	'PROCEDURE p (SQLSTATE); DEALLOCATE DESCRIPTOR d;':                                                                                                                                                                                                                                 [
		'B031',
		'B035',
	]
	"PROCEDURE p (SQLSTATE, :n INT); GET DESCRIPTOR 'd' :n = COUNT;":                                                                                                                                                                                                                   ['B031']
	"PROCEDURE p (SQLSTATE, :n INT); GET DESCRIPTOR 'd' VALUE 1 :n = KEY_MEMBER;":                                                                                                                                                                                                      [
		'B031',
		'T301',
	]
	"PROCEDURE p (SQLSTATE); SET DESCRIPTOR 'd' COUNT = 1;":                                                                                                                                                                                                                            ['B031']
	// Prepared statements. A literal is an extension.
	flagging_prepare:                                                                                                                                                                                                                                                                   ['B031']
	"PROCEDURE s (SQLSTATE); PREPARE s FROM 'VALUES 1';":                                                                                                                                                                                                                               [
		'B031',
		'V117-01',
	]
	'PROCEDURE p (SQLSTATE, :q CHAR(9)); EXECUTE IMMEDIATE :q;':                                                                                                                                                                                                                        ['B031']
	"PROCEDURE p (SQLSTATE); EXECUTE IMMEDIATE 'COMMIT';":                                                                                                                                                                                                                              [
		'B031',
		'V118-01',
	]
	flagging_prepare + 'PROCEDURE p (SQLSTATE); DEALLOCATE PREPARE s;':                                                                                                                                                                                                                 [
		'B031',
		'B032',
	]
	flagging_prepare + "PROCEDURE p (SQLSTATE); DESCRIBE s USING DESCRIPTOR 'd';":                                                                                                                                                                                                      ['B031']
	flagging_prepare + 'PROCEDURE p (SQLSTATE); DESCRIBE s USING SQL DESCRIPTOR d;':                                                                                                                                                                                                    [
		'B031',
		'B035',
	]
	flagging_prepare + 'PROCEDURE p (SQLSTATE, :n INT); EXECUTE s USING :n;':                                                                                                                                                                                                           ['B031']
	flagging_prepare + 'PROCEDURE p (SQLSTATE, :n INT); EXECUTE s INTO :n;':                                                                                                                                                                                                            [
		'B031',
		'B032',
	]
	flagging_prepare + 'PROCEDURE p (SQLSTATE); EXECUTE s INTO DESCRIPTOR d;':                                                                                                                                                                                                          [
		'B031',
		'B032',
		'B035',
	]
	// A statement or a host parameter can be named DESCRIPTOR.
	flagging_prepare + 'PROCEDURE p (SQLSTATE, :descriptor INT, :i INT); EXECUTE s USING :descriptor INDICATOR :i;':                                                                                                                                                                    ['B031']
	'PROCEDURE s (SQLSTATE, :q CHAR(9)); PREPARE descriptor FROM :q; PROCEDURE p (SQLSTATE); EXECUTE descriptor;':                                                                                                                                                                      ['B031']
	// Dynamic cursors, each statement on its own.
	flagging_dynamic_cursor + 'PROCEDURE p (SQLSTATE, :n INT); OPEN c USING :n;':                                                                                                                                                                                                       ['B031']
	flagging_dynamic_cursor + 'PROCEDURE p (SQLSTATE, :n INT); FETCH c INTO :n;':                                                                                                                                                                                                       ['B031']
	flagging_dynamic_cursor + 'PROCEDURE p (SQLSTATE, :n INT); FETCH NEXT FROM c INTO :n;':                                                                                                                                                                                             [
		'B031',
		'F432',
	]
	flagging_dynamic_cursor + 'PROCEDURE p (SQLSTATE); CLOSE c;':                                                                                                                                                                                                                       ['B031']
	flagging_dynamic_cursor + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE CURRENT OF c;':                                                                                                                                                                                              ['B031']
	flagging_dynamic_cursor + 'PROCEDURE p (SQLSTATE); UPDATE t SET x = 1 WHERE CURRENT OF c;':                                                                                                                                                                                         ['B031']
	flagging_prepare + 'DECLARE c CURSOR WITHOUT HOLD FOR s; PROCEDURE p (SQLSTATE); CLOSE c;':                                                                                                                                                                                         [
		'B031',
		'T551',
	]
	// Diagnostics.
	'PROCEDURE p (SQLSTATE, :n INT); GET DIAGNOSTICS :n = NUMBER;':                                                                                                                                                                                                                     ['F120']
	'PROCEDURE p (SQLSTATE, :n INT, :m INT); GET DIAGNOSTICS :n = TRANSACTIONS_COMMITTED, :m = ROW_COUNT;':                                                                                                                                                                             [
		'F120',
		'T511',
	]
	'PROCEDURE p (SQLSTATE, :s VARCHAR(9), :n INT); GET DIAGNOSTICS CONDITION 1 :s = MESSAGE_TEXT, :n = CONDITION_NUMBER;':                                                                                                                                                             ['F120']
	'PROCEDURE p (SQLSTATE, :s CHAR(9)); GET DIAGNOSTICS CONDITION 1 :s = MESSAGE_TEXT;':                                                                                                                                                                                               [
		'F120',
		'F122',
	]
	// Indicator parameters that have different data types, in any statement.
	'PROCEDURE p (SQLSTATE, :x INT, :i SMALLINT); DELETE FROM t WHERE x = :x :i; PROCEDURE q (SQLSTATE, :x INT, :i SMALLINT); SELECT x INTO :x INDICATOR :i FROM t;':                                                                                                                   []string{}
	'PROCEDURE p (SQLSTATE, :x INT, :i SMALLINT); DELETE FROM t WHERE x = :x :i; PROCEDURE q (SQLSTATE, :x INT, :i INT); SELECT x INTO :x INDICATOR :i FROM t;':                                                                                                                        ['F611']
	"PROCEDURE p (SQLSTATE, :x INT, :i SMALLINT); DELETE FROM t WHERE x = :x :i; DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :x :i AND y = ':' AND z = ':'; PROCEDURE o (SQLSTATE, :x INT, :i INT); OPEN c;":                                                                        ['F611']
	// A name that's only read by the module (not the grammar) is flagged with
	// F391 too, but not a descriptor name in a literal or an item name.
	'PROCEDURE procedure_name_18c (SQLSTATE, :parameter_name_18c INT); DELETE FROM t WHERE x = :parameter_name_18c;':                                                                                                                                                                   []string{}
	'PROCEDURE procedure_name_19ch (SQLSTATE); COMMIT;':                                                                                                                                                                                                                                ['F391']
	'PROCEDURE p (SQLSTATE, :parameter_name_19ch INT); DELETE FROM t WHERE x = :parameter_name_19ch;':                                                                                                                                                                                  ['F391']
	'PROCEDURE p (SQLSTATE, :s VARCHAR(99)); PREPARE statement_name_18c FROM :s;':                                                                                                                                                                                                      ['B031']
	'PROCEDURE p (SQLSTATE, :s VARCHAR(99)); PREPARE statement_name_19ch FROM :s;':                                                                                                                                                                                                     [
		'B031',
		'F391',
	]
	'PROCEDURE p (SQLSTATE, :s VARCHAR(99)); PREPARE "statement name 18c" FROM :s;':                                                                                                                                                                                                    ['B031']
	'PROCEDURE p (SQLSTATE, :s VARCHAR(99)); PREPARE "statement ""name"" 19" FROM :s;':                                                                                                                                                                                                 [
		'B031',
		'F391',
	]
	'PROCEDURE p (SQLSTATE); ALLOCATE DESCRIPTOR descriptor_name_19c;':                                                                                                                                                                                                                 [
		'B031',
		'B035',
		'F391',
	]
	"PROCEDURE p (SQLSTATE); ALLOCATE DESCRIPTOR 'descriptor_name_18';":                                                                                                                                                                                                                ['B031']
	'DECLARE cursor_name_19chars CURSOR FOR SELECT x FROM t; PROCEDURE o (SQLSTATE); OPEN cursor_name_19chars; PROCEDURE c (SQLSTATE); CLOSE cursor_name_19chars;':                                                                                                                     ['F391']
}

fn query_error(mut db Connection, sql_stmt string) string {
	db.query(sql_stmt) or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

// transaction_state is the state of the transaction in the storage of the
// current catalog.
fn transaction_state(db &Connection) TransactionState {
	catalog := unsafe { db.catalogs[db.current_catalog] }
	return catalog.storage.transaction_state
}
