module vsql

// api_test.v tests the rest of the V API, and the parts of statements that SQL
// tests can't reach.

import os
import time

// new_numeric_value and new_decimal_value (for an application) also accept an
// exponent.
fn test_new_numeric_and_decimal_value() {
	assert new_numeric_value('1.5e3').str() == '1500'
	assert new_numeric_value('1.5E+3').str() == '1500'
	assert new_numeric_value('-15e-1').str() == '-1.5'
	assert new_numeric_value('1.5e-3').str() == '0.0015'
	assert new_numeric_value('0.5e1').str() == '5'
	assert new_numeric_value('1.2345e2').str() == '123.45'
	assert new_numeric_value('1e309').str() == '1' + '0'.repeat(309)
	assert new_numeric_value('1.00000000000000000001e0').str() == '1.00000000000000000001'
	assert new_decimal_value('1.5e-1').typ.str() == 'DECIMAL(3, 2)'
	assert new_numeric_value('1e1001').str() == '0'
	assert new_decimal_value('1.25').str() == '1.25'
	assert new_decimal_value('1.25').typ.str() == 'DECIMAL(3, 2)'
}

// A comment doesn't end a statement, even with a semicolon or quote in it, and
// a statement that is only a comment is left out.
fn test_split_statements_with_comments() {
	assert split_statements("VALUES 1; -- it's; done") == ['VALUES 1']
	assert split_statements('VALUES 1 -- a;b\n, 2;\n-- end') == ['VALUES 1 -- a;b\n, 2']
	assert split_statements("VALUES '--';VALUES 2") == ["VALUES '--'", 'VALUES 2']

	// A comment may also end the SQL without a new line.
	mut db := open(':memory:')!
	assert db.query('VALUES 1 -- one')!.rows[0].get_string('COL1')! == '1'
}

// A semicolon in a bracketed comment (which can be nested) doesn't end a
// statement either. The text after the last semicolon is returned as it is,
// unless it's only white space and comments.
fn test_split_terminated_statements() {
	cases := {
		'VALUES 1 /* a; /* b; */ c; */;': ['VALUES 1 /* a; /* b; */ c; */', '']
		'VALUES 1; /* end */\n':          ['VALUES 1', '']
		'VALUES 1; VALUES\n':             ['VALUES 1', ' VALUES\n']
		"VALUES ';":                      ["VALUES ';"]
		'/* a; */ /* b;':                 ['/* a; */ /* b;']
	}
	for script, expected in cases {
		statements, rest := split_terminated_statements(script)
		assert [...statements, rest] == expected, script
	}
	assert split_statements('VALUES 1; VALUES 2 ') == ['VALUES 1', 'VALUES 2']
}

// ISO/IEC 9075-2:2016(E), 22.1, <direct SQL statement>
fn test_direct() {
	mut db := open(':memory:')!

	// A statement that isn't one statement ending with a semicolon, or that has
	// a parameter, is a syntax error.
	for stmt in ['VALUES 1', 'VALUES 1; VALUES 2;', 'VALUES ?;', 'VALUES :x;'] {
		db.direct(stmt) or {
			assert sqlstate_from_int(err.code()) == '42601'
			continue
		}
		assert false, stmt
	}
	assert !db.in_transaction()

	// SET CATALOG and SET SCHEMA don't start an SQL-transaction.
	db.direct("SET SCHEMA 'PUBLIC';")!
	assert !db.in_transaction()

	// Any other statement starts one, which stays active until it's committed.
	db.direct('CREATE TABLE t (x INT);')!
	assert db.in_transaction()
	db.direct('INSERT INTO t (x) VALUES (1);')!
	db.direct('COMMIT;')!
	assert !db.in_transaction()

	// An empty result of a query is no data. A query starts an SQL-transaction
	// too, but it isn't started in storage until something is changed.
	db.clear_warnings()
	assert db.direct('SELECT * FROM t WHERE x = 2;')!.rows.len == 0
	assert !db.in_transaction() && db.direct_query_transaction
	assert db.warnings.map(sqlstate_from_int(it.code())) == ['02000']
	db.clear_warnings()
	assert db.direct('SELECT * FROM t;')!.rows.len == 1
	assert db.warnings.len == 0
	assert db.direct('COMMIT;')!.msg == 'COMMIT'
	assert !db.direct_query_transaction
	db.direct('VALUES 1;')!
	db.direct('INSERT INTO t (x) VALUES (2);')!
	assert db.in_transaction() && !db.direct_query_transaction
	db.direct('COMMIT;')!
	db.direct('VALUES 1;')!

	// START TRANSACTION can't be used while the SQL-transaction is active.
	db.direct('START TRANSACTION;') or {
		assert sqlstate_from_int(err.code()) == '25001'
		assert db.direct('ROLLBACK;')!.msg == 'ROLLBACK'
		db.direct('START TRANSACTION;')!
		assert db.in_transaction()
		db.direct('ROLLBACK;')!

		// With autocommit, each statement commits on its own.
		db.direct('INSERT INTO t (x) VALUES (3);', autocommit: true)!
		assert !db.in_transaction() && !db.direct_query_transaction
		assert db.direct('SELECT * FROM t WHERE x = 3;', autocommit: true)!.rows.len == 1
		assert !db.in_transaction() && !db.direct_query_transaction

		// AND CHAIN doesn't start an SQL-transaction if there isn't one. The next
		// one has the same characteristics, even if a query started the last one.
		db.direct('COMMIT AND CHAIN;')!
		assert !db.is_active()
		db.direct('ROLLBACK AND CHAIN;')!
		assert !db.is_active()
		db.direct('VALUES 1;')!
		db.direct('COMMIT AND CHAIN;')!
		assert db.direct_query_transaction && !db.in_transaction()
		db.direct('ROLLBACK;')!
		assert !db.is_active()

		// The access mode of an SQL-transaction that a query started is kept
		// when a statement that writes starts it in storage.
		db.direct('SET TRANSACTION READ ONLY;')!
		db.direct('VALUES 1;')!
		assert db.direct_query_transaction
		db.direct('INSERT INTO t (x) VALUES (4);') or {
			assert sqlstate_from_int(err.code()) == '25006'
		}
		assert db.in_transaction() && !db.direct_query_transaction
		db.direct('ROLLBACK;')!
		assert !db.transaction_read_only() || !db.in_transaction()

		// SET TRANSACTION doesn't start an SQL-transaction, and its DIAGNOSTICS
		// SIZE is for the next one, even if a query starts it.
		db.direct('SET TRANSACTION DIAGNOSTICS SIZE 1;')!
		assert !db.is_active()
		db.direct('VALUES 1;')!
		db.direct('INSERT INTO t (x) VALUES (4);')!
		assert db.condition_area_limit == 1
		db.direct('SET TRANSACTION;') or { assert sqlstate_from_int(err.code()) == '25001' }
		db.direct('ROLLBACK;')!
		db.direct('SET TRANSACTION DIAGNOSTICS SIZE 2;')!
		db.direct('INSERT INTO t (x) VALUES (4);')!
		assert db.condition_area_limit == 2
		db.direct('ROLLBACK;')!
		return
	}
	assert false
}

// Each SQL-session starts with a condition area limit of 100, which a SET
// TRANSACTION in another SQL-session doesn't change.
fn test_condition_area_limit_of_new_session() ! {
	mut db := open(':memory:')!
	assert db.condition_area_limit == 100
	db.direct('SET TRANSACTION DIAGNOSTICS SIZE 1;')!
	db.direct('VALUES 1;')!
	assert db.condition_area_limit == 1

	mut db2 := open(':memory:')!
	assert db2.condition_area_limit == 100
	db2.direct('VALUES 1;')!
	assert db2.condition_area_limit == 100
}

// c_arm_fault is only called by the C tests of libvsql.
fn test_c_arm_fault() {
	assert c_arm_fault(c'wal_write', 2) == 0
	assert fault_points.armed['wal_write'] == 2
	assert c_arm_fault(c'nothing', 1) == 1
	disarm_faults()
}

// agent_sqlstate is the SQLSTATE of the error of a statement, or '' if it
// succeeds.
fn agent_sqlstate(mut a Agent, stmt string) string {
	a.direct(stmt) or { return sqlstate_from_int(err.code()) }
	return ''
}

fn test_agent() {
	// The default SQL-connection is established by the first statement that
	// isn't a connection statement. The other files are attached as catalogs.
	mut a := new_agent(':memory:', catalogs: [':memory:'])
	assert agent_sqlstate(mut a, 'VALUES 1;') == '08001'
	a = new_agent(':memory:')
	assert !a.in_transaction()
	for stmt in [';', '"";', 'VALUES;'] {
		assert agent_sqlstate(mut a, stmt) == '42601', stmt
	}
	a.direct('CREATE TABLE t (x INT);')!
	assert a.in_transaction()

	// Only the current SQL-connection can have an active SQL-transaction.
	for stmt in ["CONNECT TO ':memory:' AS 'c';", 'SET CONNECTION DEFAULT;', 'DISCONNECT CURRENT;'] {
		assert agent_sqlstate(mut a, stmt) in ['0A001', '25001'], stmt
	}
	a.direct('COMMIT;')!

	// A connection name is an identifier, and the SQL-server name is the
	// connection name when there isn't one.
	for name, code in {
		'':        '2E000'
		'x y':     '2E000'
		'x;':      '2E000'
		'1':       '2E000'
		'(':       '2E000'
		'"x':      '2E000'
		'DEFAULT': '2E000'
		'SELECT':  '2E000'
		'name':    ''
		' c ':     ''
		'"c"':     ''
		'C':       '08002'
	} {
		assert agent_sqlstate(mut a, "CONNECT TO ':memory:' AS '${name}';") == code, name
	}
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:';") == '2E000'
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:' USER 'bob';") == '2E000'
	assert agent_sqlstate(mut a, "CONNECT TO '/does/not/exist.vsql' AS 'd';") == '08001'
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:' AS 'u' USER 'a b';") == '28000'
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:' AS 'u' USER 'SELECT';") == '28000'
	assert agent_sqlstate(mut a, "CONNECT TO ':memory:' AS 'u' USER 'bob';") == ''
	assert agent_sqlstate(mut a, 'CONNECT TO :x;') == '42601'
	assert agent_sqlstate(mut a, 'CONNECT TO DEFAULT;') == '08002'

	// The connection is a different SQL-server. The SQL-transaction that the
	// query started is still active.
	assert agent_sqlstate(mut a, 'SELECT * FROM t;') == '42P01'
	assert agent_sqlstate(mut a, 'SET CONNECTION DEFAULT;') == '0A001'
	a.direct('ROLLBACK;')!
	a.direct('SET CONNECTION DEFAULT;')!
	assert a.direct('SELECT * FROM t;')!.rows.len == 0
	assert a.warnings.map(sqlstate_from_int(it.code())) == ['02000']
	a.direct('ROLLBACK;')!
	assert agent_sqlstate(mut a, "SET CONNECTION 'nope';") == '08003'

	// A connection statement can't be prepared.
	mut conn := a.current
	conn.query('CONNECT TO DEFAULT') or { assert sqlstate_from_int(err.code()) == '42601' }

	// After a connection statement, there's no implicit connection.
	a.direct('DISCONNECT DEFAULT;')!
	assert agent_sqlstate(mut a, 'SET CONNECTION DEFAULT;') == '08003'
	assert agent_sqlstate(mut a, 'DISCONNECT CURRENT;') == '08003'
	assert agent_sqlstate(mut a, 'VALUES 1;') == '08003'
	a.direct("SET CONNECTION 'Name';")!
	a.direct('DISCONNECT CURRENT;')!
	assert agent_sqlstate(mut a, "DISCONNECT 'name';") == '08003'
	a.direct('CONNECT TO DEFAULT;')!
	a.direct('DISCONNECT ALL;')!
	assert a.all_connections().len == 0

	// The end of the SQL-session commits, or rolls back.
	a.direct('CONNECT TO DEFAULT;')!
	a.direct('CREATE TABLE t (x INT);')!
	assert a.in_transaction()
	a.close(true)!
	assert !a.in_transaction() && a.all_connections().len == 0
	a.connect_default()!
	a.connect_default()!
	a.close(false)!
}

// The reserved words are sorted and leave out the non-reserved words (which
// can be identifiers), operators, literals and E.
fn test_reserved_words() {
	words := reserved_words()
	assert 'SELECT' in words
	assert 'FROM' in words
	assert 'NAME' !in words
	assert 'E' !in words
	assert 'ABORT' !in words
	assert 'LIMIT' !in words
	assert !words.any(it.starts_with('OPERATOR_') || it.starts_with('LITERAL_'))
	mut sorted := words.clone()
	sorted.sort()
	assert words == sorted
}

// An extension keyword can be an identifier, so it can't be reserved as well.
fn test_extension_keywords() {
	words := extension_keywords()
	assert 'LIMIT' in words
	assert !words.any(it in reserved_words())
	mut sorted := words.clone()
	sorted.sort()
	assert words == sorted
}

// A DEFAULT can be up to the maximum length of a VARCHAR, but its text (with
// the quotes) is then too long for the COLUMN_DEFAULT of the COLUMNS view.
fn test_information_schema_truncated_column_default() {
	column := Column{
		name:          Identifier{
			sub_entity_name: 'X'
		}
		typ:           new_type('CHARACTER VARYING', max_character_length, 0)
		default_value: new_ref(DefaultOption(new_varchar_value('a'.repeat(max_character_length))))
	}

	assert column_default(column).string_value() == 'TRUNCATED'
}

// A CHECK_CLAUSE that's too long for the INFORMATION_SCHEMA is NULL.
fn test_information_schema_truncated_check_clause() {
	row := check_constraints_view_row('C', Table{}, 'T_CHECK_1', 'a'.repeat(max_character_length + 1))

	assert row[3].is_null
}

// The DATA SOURCE NAME and SERVER NAME of SQL_IMPLEMENTATION_INFO are the path
// of the database (which the SQL tests can't show, since it's different for
// each one), and the DBMS VERSION for a release (which a test build isn't).
fn test_sql_implementation_info() ! {
	mut db := open(':memory:')!
	defer {
		db.close()
	}
	mut names := []string{}
	for row in db.query("SELECT character_value FROM information_schema.sql_implementation_info WHERE implementation_info_id IN ('2', '13')")! {
		names << row.get_string('CHARACTER_VALUE')!
	}
	assert names == [':memory:', ':memory:']

	assert dbms_version('', '') == '00.00.0000'
	assert dbms_version('v1.2.3', '2026-11-11') == '01.02.0003 v1.2.3 2026-11-11'
	assert dbms_version('v12', '2026-11-11') == '12.00.0000 v12 2026-11-11'
}

// column_names is only used by vorm, so it's tested directly.
fn test_table_column_names() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER, y INTEGER GENERATED ALWAYS AS (x + 1))')!
	tables := db.catalog().schema_tables('PUBLIC')!

	assert tables.len == 1
	assert tables[0].column_names() == ['X', 'Y']
}

// The INFORMATION_SCHEMA and other virtual tables are in the catalog, so they
// can be listed like any other schema and table.
fn test_catalog_virtual_tables() ! {
	mut db := open(':memory:')!
	db.register_virtual_table('CREATE TABLE v (x INTEGER)', fn (mut t VirtualTable) ! {
		t.done()
	})!
	mut catalog := db.catalog()

	schemas := catalog.schemas()!
	assert schemas.filter(it.name == 'PUBLIC').map(it.is_virtual) == [false]
	assert schemas.filter(it.name == 'INFORMATION_SCHEMA').map(it.is_virtual) == [true]

	mut public_tables := catalog.schema_tables('PUBLIC')!.map('${it.name.entity_name} ${it.is_virtual}')
	public_tables.sort()
	assert public_tables == ['V true']
	assert catalog.schema_tables('INFORMATION_SCHEMA')!.any(it.name.entity_name == 'TABLES'
		&& it.is_virtual)
}

fn test_current_catalog_name() {
	mut db := open(':memory:')!
	assert db.current_catalog_name() == ':memory:'
}

// NULL can only be the value of these with a dynamic parameter.
fn test_set_session_names_null() ! {
	mut db := open(':memory:')!
	params := {
		'?1': new_null_value(.is_varchar)
	}
	for sql_text, sqlstate in {
		'SET NAMES ?':   '2C000'
		'SET SCHEMA ?':  '3F000'
		'SET CATALOG ?': '3D000'
	} {
		mut stmt := db.prepare(sql_text)!
		stmt.query(params) or {
			assert sqlstate_from_int(err.code()) == sqlstate
			continue
		}
		assert false, sql_text
	}
}

fn test_prepared_stmt_dynamic_parameters() {
	mut db := open(':memory:')!
	mut stmt := db.prepare("VALUES ROW(CAST(? AS INTEGER), '?', CAST(? AS VARCHAR(1)))")!
	assert stmt.dynamic_parameter_count() == 2
	assert stmt.dynamic_parameter_type(1)?.str() == 'INTEGER'
	assert stmt.dynamic_parameter_type(2)?.str() == 'CHARACTER VARYING(1)'
	assert stmt.dynamic_parameter_type(3) == none

	// Each value is cast to the type of its parameter.
	columns := stmt.columns({
		'?1': new_varchar_value('1')
		'?2': new_varchar_value('a')
	})!
	assert columns.map(it.typ.str()) == ['INTEGER', 'CHARACTER(1)', 'CHARACTER VARYING(1)']
	if _ := stmt.columns({
		'?1': new_varchar_value('x')
		'?2': new_varchar_value('a')
	})
	{
		assert false
	}

	// A statement that can't be compiled when it's parsed (because the table
	// doesn't exist yet, which prepare would raise) doesn't know the types of
	// its parameters, so they have the types of their values.
	mut insert := db.parse('INSERT INTO later (x) VALUES (?)')!
	assert insert.dynamic_parameter_type(1) == none
	db.query('CREATE TABLE later (x DOUBLE PRECISION)')!
	insert.query({
		'?1': new_integer_value(3)
	})!
	assert db.query('SELECT x FROM later')!.rows[0].get_f64('X')! == 3

	// So a dynamic parameter that is the start position of a SUBSTRING only has
	// to be a whole number.
	mut substring := db.parse('SELECT SUBSTRING(s FROM ?) AS s FROM later2')!
	db.query('CREATE TABLE later2 (s VARCHAR(10))')!
	db.query("INSERT INTO later2 (s) VALUES ('hello')")!
	assert substring.query({
		'?1': new_double_precision_value(2)
	})!.rows[0].get_string('S')! == 'ello'

	// A statement that's prepared while another statement is executing keeps
	// the closures that are made to find the types of its parameters.
	db.frame_active = true
	nested := db.prepare('VALUES CAST(? AS INTEGER)')!
	missing := db.parse('SELECT x FROM missing WHERE x = ?')!
	db.frame_active = false
	assert nested.dynamic_parameter_type(1)?.str() == 'INTEGER'
	assert missing.dynamic_parameter_type(1) == none

	// The value of a dynamic parameter that's compiled to find its type is
	// never needed, but it would be the null value.
	assert parameter_result('', new_type('INTEGER', 0, 0)).run(mut db, Row{}, map[string]Value{})!.is_null

	// A statement that doesn't return rows has no columns.
	mut create := db.prepare('CREATE TABLE t (x INT)')!
	assert create.columns({})!.len == 0

	mut explain := db.prepare('EXPLAIN VALUES 1')!
	assert explain.columns({})!.map(it.name.sub_entity_name) == ['EXPLAIN']
}

// A table or column that doesn't exist is an error when a statement is
// prepared (#651). A schema statement is only checked when it's executed, so
// the table it creates can only be used by statements prepared after that.
fn test_prepare_resolves_names() ! {
	mut db := open(':memory:')!
	assert prepare_error(mut db, 'SELECT * FROM t') == '42P01 no such table: ":memory:".PUBLIC.T'
	assert prepare_error(mut db, 'INSERT INTO t (x) VALUES (1)') == '42P01 no such table: ":memory:".PUBLIC.T'
	assert prepare_error(mut db, 'SELECT * FROM nope.t') == '3F000 invalid schema name: NOPE'
	mut create := db.prepare('CREATE TABLE t (x INT)')!
	assert prepare_error(mut db, 'SELECT * FROM t') == '42P01 no such table: ":memory:".PUBLIC.T'
	create.query({})!

	// The table is empty, so none of these would fail when they're executed.
	assert prepare_error(mut db, 'SELECT y FROM t') == '42601 syntax error: unknown column: ":memory:".PUBLIC.Y'
	assert prepare_error(mut db, 'INSERT INTO t (y) VALUES (?)') == '42703 no such column: Y'
	assert prepare_error(mut db, 'INSERT INTO t (x) SELECT y FROM t') == '42601 syntax error: unknown column: ":memory:".PUBLIC.Y'
	assert prepare_error(mut db, 'UPDATE t SET y = 1') == '42703 no such column: Y'
	assert prepare_error(mut db, 'UPDATE t SET x = y') == '42601 syntax error: unknown column: ":memory:".PUBLIC.Y'
	assert prepare_error(mut db, 'UPDATE t AS u SET x = t.x') == '42601 syntax error: unknown column: ":memory:".PUBLIC.T.X'
	assert prepare_error(mut db, 'DELETE FROM t WHERE y = 1') == '42601 syntax error: unknown column: ":memory:".PUBLIC.Y'
	assert prepare_error(mut db, 'DECLARE c CURSOR FOR SELECT y FROM t') == '42601 syntax error: unknown column: ":memory:".PUBLIC.Y'
	assert prepare_error(mut db, 'SELECT * FROM t AS a, t AS b WHERE x = 1') == '42702 ambiguous column: X'
	assert prepare_error(mut db, 'UPDATE t SET y = 1 WHERE CURRENT OF c') == '42703 no such column: Y'
	assert prepare_error(mut db, 'UPDATE t AS u SET x = u.x + ?') == ''
	assert prepare_error(mut db, 'UPDATE t SET x = DEFAULT') == ''
	assert prepare_error(mut db, 'DROP TABLE nope') == ''

	// The value of a "?" isn't known yet, so an error that depends on it can only
	// be found when it's executed.
	mut stmt := db.prepare('SELECT ABS(CAST(? AS INTEGER)) AS y FROM t')!
	db.query('INSERT INTO t (x) VALUES (1)')!
	assert stmt.query({
		'?1': new_integer_value(-2)
	})!.rows[0].get_int('Y')! == 2

	// The names are resolved again each time it's executed.
	db.query('DROP TABLE t')!
	mut failed := false
	stmt.query({
		'?1': new_integer_value(-2)
	}) or {
		failed = true
		assert err.msg() == 'no such table: ":memory:".PUBLIC.T'
	}
	assert failed
	db.query('CREATE TABLE t (x INT)')!
	assert stmt.query({
		'?1': new_integer_value(-2)
	})!.rows.len == 0
}

fn prepare_error(mut db Connection, sql_stmt string) string {
	db.prepare(sql_stmt) or { return '${sqlstate_from_int(err.code())} ${err.msg()}' }

	return ''
}

fn test_command_function() {
	mut db := open(':memory:')!
	for sql, want in {
		'ALTER SEQUENCE s RESTART':              'ALTER SEQUENCE 134'
		'ALTER TABLE t ADD COLUMN y INT':        'ALTER TABLE 4'
		'COMMIT':                                'COMMIT WORK 11'
		'DELETE FROM t':                         'DELETE WHERE 19'
		'DROP SCHEMA s RESTRICT':                'DROP SCHEMA 31'
		'DROP SEQUENCE s':                       'DROP SEQUENCE 135'
		'DROP TABLE t':                          'DROP TABLE 32'
		'INSERT INTO t (x) VALUES (1)':          'INSERT 50'
		'VALUES 1':                              'SELECT CURSOR 85'
		'ROLLBACK':                              'ROLLBACK WORK 62'
		'CREATE SCHEMA s':                       'CREATE SCHEMA 64'
		'CREATE SEQUENCE s':                     'CREATE SEQUENCE 133'
		'CREATE INDEX i ON t (x)':               'CREATE INDEX -3'
		'DROP INDEX i':                          'DROP INDEX -4'
		"SET CATALOG 'c'":                       'SET CATALOG 66'
		'SET CONSTRAINTS ALL DEFERRED':          'SET CONSTRAINT 68'
		"SET SCHEMA 's'":                        'SET SCHEMA 74'
		'START TRANSACTION':                     'START TRANSACTION 111'
		'CREATE TABLE t (x INT)':                'CREATE TABLE 77'
		'UPDATE t SET x = 1':                    'UPDATE WHERE 82'
		'EXPLAIN VALUES 1':                      'EXPLAIN -1'
		'CLOSE c':                               'CLOSE CURSOR 9'
		'DECLARE c CURSOR FOR VALUES 1':         'DECLARE CURSOR -2'
		'DELETE FROM t WHERE CURRENT OF c':      'DELETE CURSOR 18'
		'FETCH c':                               'FETCH 45'
		'OPEN c':                                'OPEN 53'
		'UPDATE t SET x = 1 WHERE CURRENT OF c': 'UPDATE CURSOR 81'
		'DELETE FROM t u WHERE CURRENT OF c':    'DELETE CURSOR 18'
		'UPDATE t u SET x=1 WHERE CURRENT OF c': 'UPDATE CURSOR 81'
	} {
		stmt := db.parse(sql)!
		name, code := stmt.command_function()
		assert '${name} ${code}' == want, sql
	}
}

fn test_positioned_cursor() {
	mut db := open(':memory:')!
	for sql, want in {
		'DELETE FROM t':                             ''
		'DELETE FROM t WHERE CURRENT OF c':          'C'
		'UPDATE t SET x = 1 WHERE CURRENT OF "c 1"': 'c 1'
	} {
		stmt := db.parse(sql)!
		assert stmt.positioned_cursor() == want, sql
	}
}

fn test_features_of_routine_invocation() ! {
	mut db := open(':memory:')!
	db.register_function('twice(float) float', fn (_ FunctionContext, a []Value) !Value {
		return new_double_precision_value(a[0].f64_value() * 2)
	})!

	assert db.prepare('VALUES twice(1)')!.features() == ['F641', 'F661']
	assert db.prepare('VALUES twice(?)')!.features() == ['B031', 'B033', 'F641', 'F661']
}

// A rule that needs the catalog isn't flagged if the catalog can't be read, but
// it's not an error (see tests/std_1_8_5_flagging_name_resolution.sql).
fn test_features_without_catalog() ! {
	dir := os.join_path(os.temp_dir(), 'vsql-features-${os.getpid()}')
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}

	mut db := open(os.join_path(dir, 'test.vsql'))!
	db.query('CREATE TABLE t (x INT NOT NULL)')!
	stmt := db.prepare('DELETE FROM t WHERE x IN (SELECT x FROM t)')!
	assert stmt.features() == ['F781']

	arm_fault('open', 1)!
	defer {
		disarm_faults()
	}
	assert stmt.features() == []
}

// A prepared statement has a new statement timestamp each time it's executed.
//
// ISO/IEC 9075-2:2016(E), 13.4, <SQL procedure statement>, General Rules, 4
fn test_prepared_statement_timestamp() ! {
	mut db := open(':memory:')!
	mut ticking := &SQLTestTickingClock{}
	db.now = ticking.now
	mut stmt := db.prepare('VALUES ROW(LOCALTIME, LOCALTIME)')!
	for want in ['14:05:03', '14:05:04'] {
		row := stmt.query(map[string]Value{})!.rows[0]
		assert row.get_string('COL1')! == want
		assert row.get_string('COL2')! == want
	}
}

// A connection keeps each statement that it parses (up to statement_cache_size
// of them), so the same text isn't parsed again. The statements that keep
// running stay cached when many others only run once.
fn test_statement_cache() ! {
	mut db := open(':memory:')!
	db.query('VALUES 0')!
	for i in 1 .. statement_cache_size * 3 {
		db.query('VALUES ${i}')!
		db.query('VALUES 0')!
	}
	assert db.statement_cache.slots.len == statement_cache_size
	assert db.statement_cache.slot_of.len == statement_cache_size
	assert 'VALUES 0' in db.statement_cache.slot_of
	assert 'VALUES 1' !in db.statement_cache.slot_of
	assert 'VALUES ${statement_cache_size * 3 - 1}' in db.statement_cache.slot_of

	// A statement that's too long isn't kept.
	long := 'VALUES 0' + ' '.repeat(statement_cache_max_length)
	assert db.query(long)!.rows[0].get_int('COL1')! == 0
	assert long !in db.statement_cache.slot_of
}

fn test_cast() {
	mut db := open(':memory:')!
	assert db.cast(new_varchar_value('12'), new_type('INTEGER', 0, 0))!.int_value() == 12
	assert db.cast(new_null_value(.is_integer), new_type('DATE', 0, 0))!.is_null
	assert db.cast(new_varchar_value('2026-10-26'), new_type('DATE', 0, 0))!.str() == '2026-10-26'
	assert db.cast(new_varchar_value('abc'), new_type('CHARACTER VARYING', 2, 0))!.str() == 'ab'
	assert db.cast(new_varchar_value('true'), new_type('BOOLEAN', 0, 0))!.bool_value() == .is_true
	assert db.cast(new_boolean_value(true), new_type('CHARACTER VARYING', 10, 0))!.str() == 'TRUE'

	// A TIME that's cast to a TIMESTAMP is on the current date, which is read
	// each time (it isn't the date of the last statement).
	db.now = sql_test_now
	db.query('VALUES 1')!
	db.now = fn () (time.Time, i16) {
		now, offset := sql_test_now()
		return now.add_days(1), offset
	}
	t := new_time_value('10:00:00')!
	assert db.cast(t, new_type('TIMESTAMP WITHOUT TIME ZONE', 0, 0))!.str() == '2022-07-05T10:00:00'
	assert db.store_assignment(t, new_type('TIMESTAMP WITHOUT TIME ZONE', 0, 0))!.str() == '2022-07-05T10:00:00'
	db.cast(new_varchar_value('a'), new_type('CHARACTER VARYING', max_character_length + 1,
		0)) or {
		assert err.code() != 0
		return
	}
	assert false
}

fn test_version() {
	// Tests don't run on a release build.
	assert build_version() == ''
	assert build_commit() == ''
	assert build_v_version().starts_with('0.')
	assert !build_v_version().contains(' ')
	assert build_v_commit() != ''
	assert build_date().len == 10
	assert build_c_compiler() != ''
	assert release_value('v0.34.0') == 'v0.34.0'
}

// A result column is unnamed when the query didn't name it (it has a name like
// COL1).
fn test_column_unnamed() {
	mut db := open(':memory:')!
	result := db.query('SELECT x, x + 1, x + 2 AS y FROM (VALUES 1) AS t (x)')!
	assert result.columns.map(it.unnamed) == [false, true, false]

	values := db.query('VALUES ROW(1, 2)')!
	assert values.columns.map(it.unnamed) == [true, true]
}

// The primary key or preferred candidate key of a result is only known for a
// query of one base table that isn't grouped (Column.key_type).
fn test_column_key_type() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (a INT, b INT NOT NULL, c INT NOT NULL, d INT, e INT NOT NULL, PRIMARY KEY (d, a), UNIQUE (b, c), UNIQUE (c), UNIQUE (e), UNIQUE (a), UNIQUE (b) DEFERRABLE)')!
	db.query('CREATE TABLE u (x INT NOT NULL, y INT NOT NULL, z INT NOT NULL, UNIQUE (y, z), UNIQUE (x, z))')!
	db.query('CREATE TABLE v (x INT NOT NULL, y INT NOT NULL, UNIQUE (x), UNIQUE (y))')!
	db.query('CREATE TABLE w (x INT NOT NULL, y INT NOT NULL, UNIQUE (y), UNIQUE (x))')!
	db.query('CREATE TABLE n (x INT)')!
	db.query('CREATE TABLE s (x INT NOT NULL, y INT NOT NULL, UNIQUE (y), UNIQUE (x, y))')!
	for sql, want in {
		'SELECT * FROM t':                                   [1, 0, 0, 1, 0]
		'SELECT d, a, d, a FROM t WHERE a > 0 ORDER BY b':   [1, 1, 0, 0]
		'SELECT DISTINCT t.* FROM t FETCH FIRST 1 ROW ONLY': [1, 0, 0, 1, 0]
		'SELECT x.d, a + 0, x.a AS z FROM t AS x':           [1, 0, 1]
		'SELECT q, p FROM t AS x (p, b, c, q, e)':           [1, 1]
		'SELECT a, b, c, e FROM t':                          [2, 0, 0, 0]
		'SELECT b, c FROM t':                                [0, 2]
		'SELECT e, b FROM t':                                [2, 0]
		'SELECT b, a, d FROM t AS d':                        [0, 1, 1]
		'SELECT z, y, x FROM u':                             [2, 2, 0]
		'SELECT y, x FROM v':                                [2, 0]
		'SELECT y, x FROM w':                                [2, 0]
		'SELECT x, y FROM s':                                [0, 2]
		'SELECT x FROM n':                                   [0]
		'SELECT d, a FROM t GROUP BY d, a':                  [0, 0]
		'SELECT COUNT(*) FROM t':                            [0]
		'SELECT * FROM t AS x JOIN n ON TRUE':               [0, 0, 0, 0, 0, 0]
		'SELECT * FROM (SELECT * FROM t) AS x':              [0, 0, 0, 0, 0]
		'SELECT 1':                                          [0]
		'VALUES 1':                                          [0]
		'SELECT d, a FROM t UNION SELECT d, a FROM t':       [0, 0]
	} {
		mut stmt := db.prepare(sql)!
		assert stmt.columns(map[string]Value{})!.map(it.key_type) == want, sql
	}

	// A table of the INFORMATION_SCHEMA is a view, which has no known keys.
	mut tables := db.query('SELECT * FROM information_schema.table_constraints')!
	assert tables.columns.all(it.key_type == 0)

	// A reference to a column of the outer query isn't a counterpart.
	result := db.query('SELECT (SELECT t.d FROM t AS x) FROM t')!
	assert result.columns.map(it.key_type) == [0]
}

// A prepared positioned UPDATE is checked like any other. A cursor opened by
// PreparedStmt.open_cursor (a dynamic cursor, for the SQL/CLI and a module)
// without an <updatability clause> isn't updatable if it's ordered, and a sort
// key column can't be assigned through it.
fn test_positioned_update_of_sort_key() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER, y INTEGER)')!
	db.query('INSERT INTO t (x, y) VALUES (1, 2)')!
	db.query('START TRANSACTION')!

	db.query('DECLARE c CURSOR FOR SELECT x, y FROM t ORDER BY x FOR UPDATE')!
	db.query('OPEN c')!
	db.query('FETCH NEXT FROM c')!
	mut update_x := db.prepare('UPDATE t SET x = 5 WHERE CURRENT OF c')!
	mut failed := false
	update_x.query({}) or {
		failed = true
		assert err.code() == sqlstate_to_int('42601')
	}
	assert failed
	mut update_y := db.prepare('UPDATE t SET y = 5 WHERE CURRENT OF c')!
	assert update_y.query({})!.msg == 'UPDATE 1'

	mut stmt := db.prepare('SELECT x, y FROM t ORDER BY x')!
	stmt.open_cursor('D', false, {})!
	db.position_cursor('D', 0)!
	failed = false
	db.query('UPDATE t SET x = 5 WHERE CURRENT OF d') or {
		failed = true
		assert err.code() == sqlstate_to_int('34000')
	}
	assert failed
}

// conflicting_cursor is the cursor of a warning: cursor operation conflict. A row
// that was deleted through the cursor can be positioned on again (by the
// SQL/CLI), but it can't be changed.
fn test_cursor_operation_conflict() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER)')!
	db.query('INSERT INTO t (x) VALUES (1), (2)')!
	db.query('START TRANSACTION')!

	mut stmt := db.prepare('SELECT x FROM t')!
	stmt.open_cursor('C', false, {})!
	db.position_cursor('C', 0)!
	db.query('DELETE FROM t WHERE CURRENT OF c')!
	db.position_cursor('C', 0)!
	db.query('DELETE FROM t WHERE CURRENT OF c') or {
		assert err.code() == sqlstate_to_int('24000')
		assert conflicting_cursor(err) == none
	}

	db.position_cursor('C', 1)!
	db.query('DELETE FROM t WHERE x = 2')!
	db.clear_warnings()
	db.query('DELETE FROM t WHERE CURRENT OF c')!
	assert conflicting_cursor(db.warnings[0])? == 'C'
}

// A cursor opened by PreparedStmt.open_cursor (for the SQL/CLI) is positioned
// with position_cursor, so a positioned DELETE can change its current row.
fn test_open_cursor() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER)')!
	db.query('INSERT INTO t (x) VALUES (1), (2), (0)')!
	db.query('START TRANSACTION')!

	mut stmt := db.prepare('SELECT x FROM t WHERE x > ?')!
	result := stmt.open_cursor('C', false, {
		'?1': new_integer_value(1)
	})!
	assert result.rows.map(it.get('X')!.int_value()) == [2]

	db.position_cursor('C', 1)!
	db.query('DELETE FROM t WHERE CURRENT OF c') or {
		assert err.code() == sqlstate_to_int('24000')
	}
	db.position_cursor('C', 0)!
	assert db.query('DELETE FROM t WHERE CURRENT OF c')!.msg == 'DELETE 1'

	// The name can't be used again until the cursor is removed.
	stmt.open_cursor('C', false, {
		'?1': new_integer_value(1)
	}) or { assert err.code() == sqlstate_to_int('42P03') }
	db.remove_cursor('C')
	db.position_cursor('C', 0) or { assert err.code() == sqlstate_to_int('34000') }

	// A cursor that can't be opened isn't declared.
	mut divide := db.prepare('SELECT 1 / x FROM t')!
	divide.open_cursor('C', false, {}) or { assert err.code() == sqlstate_to_int('22012') }
	mut all := db.prepare('SELECT x FROM t')!
	assert all.open_cursor('C', false, {})!.rows.len == 2

	// Outside of a transaction, the cursor is closed when the statement ends.
	db.query('COMMIT')!
	stmt.open_cursor('D', false, {
		'?1': new_integer_value(0)
	}) or { assert err.code() == sqlstate_to_int('24000') }
	assert all.open_cursor('D', true, {})!.rows.len == 2
}

// A query opened by PreparedStmt.open_cursor can have an <updatability
// clause>. Without a cursor, it's a syntax error.
fn test_open_cursor_updatability() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER, y INTEGER)')!
	db.query('INSERT INTO t (x, y) VALUES (1, 2)')!
	db.query('START TRANSACTION')!

	// FOR READ ONLY isn't updatable, even though the query is.
	mut read_only := db.prepare('SELECT x, y FROM t FOR READ ONLY')!
	read_only.open_cursor('R', false, {})!
	db.position_cursor('R', 0)!
	mut failed := false
	db.query('DELETE FROM t WHERE CURRENT OF r') or {
		failed = true
		assert err.code() == sqlstate_to_int('34000')
	}
	assert failed

	// FOR UPDATE OF only allows the columns in the list.
	mut update_y := db.prepare('SELECT x, y FROM t FOR UPDATE OF y')!
	update_y.open_cursor('U', false, {})!
	db.position_cursor('U', 0)!
	failed = false
	db.query('UPDATE t SET x = 5 WHERE CURRENT OF u') or {
		failed = true
		assert err.code() == sqlstate_to_int('42601')
	}
	assert failed
	assert db.query('UPDATE t SET y = 5 WHERE CURRENT OF u')!.msg == 'UPDATE 1'

	// FOR UPDATE makes an ordered query updatable (F831), but the query must be
	// simply updatable.
	mut ordered := db.prepare('SELECT x, y FROM t ORDER BY x FOR UPDATE')!
	ordered.open_cursor('O', false, {})!
	db.position_cursor('O', 0)!
	assert db.query('DELETE FROM t WHERE CURRENT OF o')!.msg == 'DELETE 1'
	mut grouped := db.prepare('SELECT x FROM t GROUP BY x FOR UPDATE')!
	failed = false
	grouped.open_cursor('G', false, {}) or {
		failed = true
		assert err.code() == sqlstate_to_int('42601')
	}
	assert failed

	for sql in ['SELECT x FROM t FOR READ ONLY', 'SELECT x FROM t FOR UPDATE'] {
		failed = false
		db.query(sql) or {
			failed = true
			assert err.msg() == 'syntax error: FOR READ ONLY and FOR UPDATE can only be used for a cursor'
		}
		assert failed
		failed = false
		db.direct(sql + ';') or {
			failed = true
			assert err.code() == sqlstate_to_int('42601')
		}
		assert failed
		failed = false
		direct_features(sql + ';') or {
			failed = true
			assert err.code() == sqlstate_to_int('42601')
		}
		assert failed
	}
}

// A closed cursor (of the SQL/CLI) is still declared until it's removed, so a
// positioned DELETE is an invalid cursor state, rather than an invalid cursor
// name.
fn test_close_cursor() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INTEGER)')!
	db.query('INSERT INTO t (x) VALUES (1)')!
	db.query('START TRANSACTION')!

	mut stmt := db.prepare('SELECT x FROM t')!
	stmt.open_cursor('C', false, {})!
	db.position_cursor('C', 0)!
	db.close_cursor('C')
	mut failed := false
	db.query('DELETE FROM t WHERE CURRENT OF c') or {
		failed = true
		assert err.code() == sqlstate_to_int('24000')
	}
	assert failed

	db.remove_cursor('C')
	db.close_cursor('C')
	failed = false
	db.query('DELETE FROM t WHERE CURRENT OF c') or {
		failed = true
		assert err.code() == sqlstate_to_int('34000')
	}
	assert failed
}

// constraint_violated is the constraint that a statement violated.
fn constraint_violated(mut db Connection, stmt string) string {
	db.query(stmt) or {
		c := violated_constraint(err) or { return 'none' }
		return '${c.catalog_name}.${c.schema_name}.${c.entity_name}'
	}
	return 'ok'
}

fn test_violated_constraint() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE p (id INT PRIMARY KEY, x INT NOT NULL CONSTRAINT x_positive CHECK (x > 0))')!
	db.query('CREATE TABLE c (id INT CONSTRAINT fk REFERENCES p (id), y INT CONSTRAINT y_positive CHECK (y > 0) DEFERRABLE INITIALLY DEFERRED)')!
	db.query('INSERT INTO p (id, x) VALUES (1, 1)')!
	assert constraint_violated(mut db, 'INSERT INTO p (id, x) VALUES (2, NULL)') == ':memory:.PUBLIC.P_NOT_NULL_2'
	assert constraint_violated(mut db, 'INSERT INTO c (id, y) VALUES (2, 1)') == ':memory:.PUBLIC.FK'
	assert constraint_violated(mut db, 'INSERT INTO p (id, x) VALUES (1, 1)') == ':memory:.PUBLIC.P_PRIMARY_KEY'
	assert constraint_violated(mut db, 'INSERT INTO p (id, x) VALUES (2, 0)') == ':memory:.PUBLIC.X_POSITIVE'
	db.query('START TRANSACTION')!
	db.query('INSERT INTO c (id, y) VALUES (1, 0)')!
	assert constraint_violated(mut db, 'COMMIT') == ':memory:.PUBLIC.Y_POSITIVE'
	assert constraint_violated(mut db, 'SELECT * FROM q') == 'none'
}

// table_of_condition is the table (and column) that the condition raised by a
// statement identifies.
fn table_of_condition(mut db Connection, stmt string) string {
	db.query(stmt) or {
		t := condition_table(err) or { return 'none' }
		return '${t.catalog_name}.${t.schema_name}.${t.entity_name}.${t.sub_entity_name}'
	}
	return 'ok'
}

// The table that contains a violated constraint, and the table (and column)
// that caused a syntax error or access rule violation, see condition_table.
fn test_condition_table() ! {
	mut db := open(':memory:')!
	db.query('CREATE SCHEMA s')!
	db.query('CREATE TABLE s.p (id INT PRIMARY KEY, x INT NOT NULL CONSTRAINT x_positive CHECK (x > 0), u INT UNIQUE)')!
	db.query('CREATE TABLE c (id INT CONSTRAINT fk REFERENCES s.p (id), y INT CONSTRAINT y_positive CHECK (y > 0) DEFERRABLE INITIALLY DEFERRED)')!
	db.query('CREATE UNIQUE INDEX ci ON c (id)')!
	db.query('INSERT INTO s.p (id, x, u) VALUES (1, 1, 1)')!
	db.query('INSERT INTO c (id, y) VALUES (1, 1)')!

	// Integrity constraint violations are of the table that contains the
	// constraint (or the UNIQUE index).
	assert table_of_condition(mut db, 'INSERT INTO s.p (id, x) VALUES (2, NULL)') == ':memory:.S.P.'
	assert table_of_condition(mut db, 'INSERT INTO c (id, y) VALUES (2, 1)') == ':memory:.PUBLIC.C.'
	assert table_of_condition(mut db, 'INSERT INTO s.p (id, x) VALUES (1, 1)') == ':memory:.S.P.'
	assert table_of_condition(mut db, 'INSERT INTO s.p (id, x, u) VALUES (2, 1, 1)') == ':memory:.S.P.'
	assert table_of_condition(mut db, 'INSERT INTO s.p (id, x) VALUES (2, 0)') == ':memory:.S.P.'
	assert table_of_condition(mut db, 'INSERT INTO c (id, y) VALUES (1, 1)') == ':memory:.PUBLIC.C.'
	db.query('START TRANSACTION')!
	db.query('INSERT INTO c (id, y) VALUES (NULL, 0)')!
	assert table_of_condition(mut db, 'COMMIT') == ':memory:.PUBLIC.C.'

	// No such table.
	assert table_of_condition(mut db, 'SELECT * FROM q') == ':memory:.PUBLIC.Q.'
	assert table_of_condition(mut db, 'DELETE FROM s.q') == ':memory:.S.Q.'
	assert table_of_condition(mut db, 'SELECT q.* FROM c') == ':memory:.PUBLIC.Q.'
	assert table_of_condition(mut db, 'UPDATE c SET y = q.y') == ':memory:.PUBLIC.Q.'

	// No such column (or an unknown column, which is a syntax error) is only
	// of a table if it was looked for in one table.
	assert table_of_condition(mut db, 'INSERT INTO s.p (id, z) VALUES (3, 1)') == ':memory:.S.P.Z'
	assert table_of_condition(mut db, 'UPDATE c SET z = 1') == ':memory:.PUBLIC.C.Z'
	assert table_of_condition(mut db, 'SELECT c.z FROM s.p, c') == ':memory:.PUBLIC.C.Z'
	assert table_of_condition(mut db, 'SELECT z FROM c') == '...Z'
	assert table_of_condition(mut db, 'SELECT q.z FROM c') == '...Z'
	assert table_of_condition(mut db, 'SELECT d.z FROM (SELECT id FROM c) AS d') == '...Z'
	assert table_of_condition(mut db, 'SELECT * FROM c JOIN s.p USING (z)') == '...Z'
	assert table_of_condition(mut db, 'SELECT id FROM c GROUP BY z') == '...Z'

	// Any other condition doesn't identify a table.
	assert table_of_condition(mut db, 'SELECT NEXT VALUE FOR q FROM c') == '...'
	assert table_of_condition(mut db, 'VALUES NEXT VALUE FOR q') == 'none'
	assert table_of_condition(mut db, 'SELECT 1 / 0 FROM c') == 'none'
}

fn test_invalid_cursor() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INT)')!
	db.query('DECLARE c1 CURSOR FOR SELECT x FROM t')!

	mut name := ''
	db.query('FETCH NEXT FROM c1') or { name = invalid_cursor(err) or { 'none' } }
	assert name == 'C1'

	db.query('SELECT * FROM q') or { name = invalid_cursor(err) or { 'none' } }
	assert name == 'none'
}

// CREATE INDEX waits up to create_index_timeout for another connection's
// transaction with changes to the table, then gives up. A new file can be
// changed by any version until it has an index, which raises its Write Version.
fn test_create_index_waits() ! {
	path := os.join_path(os.temp_dir(), 'vsql-sql-test-index-${os.getpid()}.vsql')
	defer {
		os.rm(path) or {}
		os.rm(session_path(path)) or {}
		os.rm(path + '.wal') or {}
	}

	mut options := default_connection_options()
	options.create_index_timeout = 30 * time.millisecond
	mut db1 := open_database(path, options)!
	defer {
		db1.close()
	}
	mut db2 := open_database(path, options)!
	defer {
		db2.close()
	}
	db1.query('CREATE TABLE t (a INT, b VARCHAR(10))')!
	mut file := os.open(path)!
	mut header := read_header(mut file)!
	file.close()
	assert header.read_version == 1 && header.write_version == 1 && header.index_id == 0

	db2.query('START TRANSACTION')!
	db2.query('INSERT INTO t (a) VALUES (1)')!
	t := start_timer()
	if _ := db1.query('CREATE INDEX t_a ON t (a)') {
		assert false, 'created an index while another transaction has changes'
	} else {
		assert '${sqlstate_from_int(err.code())} ${err.msg()}' == '55P03 cannot create index T_A while another transaction has changes to T'
	}
	assert t.elapsed() >= 30 * time.millisecond
	db2.query('COMMIT')!

	db1.query('CREATE INDEX t_b ON t (b DESC, a)')!
	db1.query('CREATE INDEX t_a ON t (a)')!
	file = os.open(path)!
	header = read_header(mut file)!
	file.close()
	assert header.read_version == 1 && header.write_version == 2 && header.index_id == 2

	db1.query('CREATE TABLE s (x INT)')!
	db1.query('CREATE INDEX s_x ON s (x)')!
	assert db1.catalog().indexes('PUBLIC')!.map(it.str()) == [
		'CREATE INDEX "S_X" ON "PUBLIC"."S" ("X");',
		'CREATE INDEX "T_A" ON "PUBLIC"."T" ("A");',
		'CREATE INDEX "T_B" ON "PUBLIC"."T" ("B" DESC, "A");',
	]

	// The write version stays when the last index is dropped.
	db1.query('DROP TABLE s RESTRICT')!
	db1.query('DROP INDEX t_a')!
	assert db1.catalog().indexes('NOSUCH')!.len == 0
	db1.query('DROP INDEX t_b')!
	file = os.open(path)!
	header = read_header(mut file)!
	file.close()
	assert header.write_version == 2
}

// A connection that's used from a thread other than the one that opened it
// still releases the closures of each statement (see PreparedStmt.query).
fn test_query_from_another_thread() ! {
	mut db := open(':memory:')!
	db.query('CREATE TABLE t (x INT)')!
	t := spawn fn (mut db Connection) !int {
		db.query('INSERT INTO t (x) VALUES (1)')!
		db.query('INSERT INTO t (x) VALUES (2)')!

		return db.query('SELECT * FROM t')!.rows.len
	}(mut db)
	assert t.wait()! == 2
	assert db.query('SELECT * FROM t')!.rows.len == 2
}

// cancel stops a statement that's executing on another thread, and does nothing
// when there isn't one.
fn test_cancel() ! {
	mut db := open(':memory:')!
	assert !db.cancel()
	db.query('CREATE TABLE t (x INT)')!
	db.query('INSERT INTO t (x) VALUES (1)')!
	for _ in 0 .. 10 {
		db.query('INSERT INTO t SELECT x FROM t')!
	}
	assert !db.cancel()

	t := spawn fn (mut db Connection) string {
		return query_error(mut db, 'SELECT COUNT(*) FROM t AS a JOIN t AS b ON a.x + b.x < 0')
	}(mut db)
	for !db.cancel() {
		time.sleep(time.millisecond)
	}
	assert t.wait() == '57014 query canceled'

	// The next statement isn't canceled.
	assert !db.cancel()
	assert db.query('SELECT * FROM t')!.rows.len == 1024
}

// The maximum length of the result of LISTAGG is too long to reach in a test, so
// a much smaller one is used to test ON OVERFLOW.
fn test_listagg_overflow() ! {
	values := ['aa', 'bb', 'cc', 'dd']
	error := ListaggOverflow{}
	without_count := ListaggOverflow{
		truncate: true
	}
	with_count := ListaggOverflow{
		truncate:   true
		with_count: true
	}

	assert listagg_result(values, ',', error, 11)! == 'aa,bb,cc,dd'
	if _ := listagg_result(values, ',', error, 10) {
		assert false
	} else {
		assert sqlstate_from_int(err.code()) == '22001'
		assert err.msg() == 'string data right truncation for CHARACTER VARYING(10)'
	}

	// As many values as fit with the filler, and the count of the others.
	assert listagg_result(values, ',', without_count, 10)! == 'aa,bb,...'
	assert listagg_result(values, ',', with_count, 10)! == 'aa,...(3)'
	assert listagg_result(values, ', ', ListaggOverflow{
		truncate:   true
		filler:     new_varchar_value('~')
		with_count: true
	}, 10)! == 'aa, ~(3)'

	// Not even the first value fits.
	assert listagg_result(values, ',', with_count, 8)! == ',...(4)'
	assert listagg_result(values, ',', with_count, 6)! == '...(4)'
	assert listagg_result(values, ',', without_count, 5)! == ',...'
	assert listagg_result(values, ',', without_count, 3)! == '...'
	assert listagg_result(['aaaaaaaaaaaa'], ',', with_count, 10)! == ',...(1)'

	// The length is in characters, not bytes.
	assert listagg_result(['é', 'é'], '', error, 2)! == 'éé'
	assert listagg_result(['é', 'é', 'é', 'é', 'é'], '', without_count, 4)! == 'é...'
}

fn test_listagg_literal_too_long() ! {
	check_listagg_literal(new_varchar_value('a'.repeat(max_character_length)))!
	if _ := check_listagg_literal(new_varchar_value('a'.repeat(max_character_length + 1))) {
		assert false
	} else {
		assert sqlstate_from_int(err.code()) == '42601'
	}
}
