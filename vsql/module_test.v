module vsql

// module_test.v tests compiling SQL-client modules ("vsql module") and
// precompiling embedded SQL ("vsql precompile"), and how they are flagged.

// module_error is the error from compiling an SQL-client module, or an empty
// string if it compiles.
fn module_error(source string) string {
	compile_module(source, 'm') or { return err.msg() }
	return ''
}

const module_header = 'MODULE LANGUAGE C SCHEMA s '

fn test_module_compile() ! {
	m := compile_module('-- A module.
MODULE "My Module" LANGUAGE C SCHEMA "it\'s" AUTHORIZATION a
PROCEDURE add (SQLSTATE, :c CHAR, :v VARCHAR(10), :s SMALLINT, :i INT,
    :i2 INTEGER, :b BIGINT, :r REAL, :d DOUBLE PRECISION, :f BOOLEAN,
    :ind SMALLINT, :unused BIGINT);
  /* ; */ INSERT INTO "t;" (a) VALUES (\'a;\\"\n\t\r\', :c, :v :ind, :s INDICATOR :ind,
    :i, :i2, :b, :r, :d, :f) -- ;
;
PROCEDURE procedure (SQLSTATE); START TRANSACTION;
procedure c2 (SQLSTATE); COMMIT;
PROCEDURE r (SQLSTATE); ROLLBACK;
PROCEDURE conn (SQLSTATE, :n CHAR(3), :u VARCHAR(4));
  CONNECT TO \'file\' AS :n USER :u;
PROCEDURE conn_default (SQLSTATE); CONNECT TO DEFAULT;
PROCEDURE conn_server (SQLSTATE); CONNECT TO \'x\';
PROCEDURE set_conn (SQLSTATE); SET CONNECTION \'x\';
PROCEDURE set_default (SQLSTATE); SET CONNECTION DEFAULT;
PROCEDURE d1 (SQLSTATE); DISCONNECT DEFAULT;
PROCEDURE d2 (SQLSTATE); DISCONNECT ALL;
PROCEDURE d3 (SQLSTATE); DISCONNECT CURRENT;
PROCEDURE d4 (SQLSTATE, :n CHAR(1)); DISCONNECT :n;
PROCEDURE set_schema (SQLSTATE); SET SCHEMA \'x\';
', 'my-module')!
	assert m.header.contains('#ifndef MY_MODULE_H')
	assert m.header.contains('void add(char SQLSTATE[6], char c[8], char v[44], short *s, long *i, long *i2, long long *b, float *r, double *d, long *f, short *ind, long long *unused);')
	assert m.source.contains('#include "my-module.h"')
	assert m.source.contains('static const char vsql_m_set_schema[] = "SET SCHEMA \'it\'\'s\'";')
	assert m.source.contains('  (void)unused;\n')
	assert m.source.contains('{SQL_CHAR, SQL_BOOLEAN, 0, (SQLPOINTER)(*f ? "TRUE" : "FALSE"), SQL_NTS}')
	assert m.source.contains('INSERT INTO \\"t;\\" (a) VALUES (\'a;\\\\\\"\\n\\t\\r\', CAST(? AS CHARACTER(1)), CAST(? AS CHARACTER VARYING(10)), CAST(? AS SMALLINT)')
	assert m.source.contains('  if (*ind < 0) {\n    vsql_m_p[1].indicator = SQL_NULL_DATA;\n  } else if (!vsql_m_string(SQLSTATE, v, 44)) {')
	assert m.source.contains('  if (*ind < 0) {\n    vsql_m_p[2].indicator = SQL_NULL_DATA;\n  }\n')
	assert m.source.contains('void procedure(char SQLSTATE[6]) {\n  vsql_m_begin("START TRANSACTION", 111);\n  vsql_m_start(SQLSTATE, SQL_TRANSACTION_READ_WRITE, SQL_TRANSACTION_SERIALIZABLE, "SET TRANSACTION DIAGNOSTICS SIZE 100");')
	assert m.source.contains('void c2(char SQLSTATE[6]) {\n  vsql_m_begin("COMMIT WORK", 11);\n  vsql_m_end(SQLSTATE, SQL_COMMIT);')
	assert m.source.contains('vsql_m_end(SQLSTATE, SQL_ROLLBACK);')
	assert m.source.contains('vsql_m_connect(SQLSTATE, "file", n, u);')
	assert m.source.contains('vsql_m_connect(SQLSTATE, NULL, NULL, NULL);')
	assert m.source.contains('vsql_m_connect(SQLSTATE, "x", NULL, NULL);')
	assert m.source.contains('vsql_m_set_connection(SQLSTATE, "x");')
	assert m.source.contains('vsql_m_set_connection(SQLSTATE, NULL);')
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'D', NULL);")
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'A', NULL);")
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'C', NULL);")
	assert m.source.contains("vsql_m_disconnect(SQLSTATE, 'n', n);")
	assert m.source.contains('vsql_m_execute(SQLSTATE, "SET SCHEMA \'x\'", 0, NULL);')

	// 17.1 <start transaction statement>, GR 2 to 5: the characteristics are
	// set by a SET TRANSACTION, then SQLStartTran has the access
	// mode and isolation level.
	m5 := compile_module(module_header +
		'PROCEDURE p (SQLSTATE); START TRANSACTION ISOLATION LEVEL READ UNCOMMITTED, DIAGNOSTICS SIZE 3; ' +
		'PROCEDURE q (SQLSTATE); start transaction /* c */ isolation level repeatable read; ' +
		'PROCEDURE r (SQLSTATE); START TRANSACTION READ ONLY;',
		'm')!
	assert m5.source.contains('  vsql_m_start(SQLSTATE, SQL_TRANSACTION_READ_ONLY, SQL_TRANSACTION_READ_UNCOMMITTED, "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED, DIAGNOSTICS SIZE 3");\n')
	assert m5.source.contains('  vsql_m_start(SQLSTATE, SQL_TRANSACTION_READ_WRITE, SQL_TRANSACTION_REPEATABLE_READ, "SET transaction   isolation level repeatable read, DIAGNOSTICS SIZE 100");\n')
	assert m5.source.contains('  vsql_m_start(SQLSTATE, SQL_TRANSACTION_READ_ONLY, SQL_TRANSACTION_SERIALIZABLE, "SET TRANSACTION READ ONLY, DIAGNOSTICS SIZE 100");\n')

	// 23.1 <get diagnostics statement> doesn't empty the diagnostics area.
	m4 := compile_module(module_header + 'PROCEDURE p (SQLSTATE, :n INT, :s CHAR(5), :c SMALLINT); GET DIAGNOSTICS :n = NUMBER, :s = DYNAMIC_FUNCTION; ' +
		'PROCEDURE q (SQLSTATE, :n BIGINT, :s VARCHAR(5), :c SMALLINT); GET DIAGNOSTICS CONDITION :c :n = CONDITION_NUMBER, :s = MESSAGE_TEXT, :n = PARAMETER_ORDINAL_POSITION; ' +
		'PROCEDURE r (SQLSTATE, :n INT); GET DIAGNOSTICS CONDITION 01 :n = CONDITION_NUMBER;',
		'm')!
	assert m4.source.contains('void p(char SQLSTATE[6], long *n, char s[24], short *c) {\n  (void)c;\n  int vsql_m_w = 0;\n')
	assert m4.source.contains('  *n = (long)vsql_m_item_number(SQL_DIAG_NUMBER, 0);\n  vsql_m_w |= vsql_m_put(s, 5, vsql_m_item_text(VSQL_M_DYNAMIC_FUNCTION, 0));\n  vsql_m_sqlstate(SQLSTATE, vsql_m_w ? "01004" : "00000");\n')
	assert m4.source.contains('  long long vsql_m_n = (long long)*c;\n  if (vsql_m_n < 1 || vsql_m_n > vsql_m_da.number) {\n    vsql_m_sqlstate(SQLSTATE, "35000");\n    return;\n  }\n  *n = (long long)vsql_m_n;\n  vsql_m_w |= vsql_m_put(s, 5, vsql_m_item_text(SQL_DIAG_MESSAGE_TEXT, vsql_m_n));\n  *n = (long long)0;\n')
	assert m4.source.contains('  long long vsql_m_n = 1LL;\n')
	assert m4.source.contains('  *n = (long)vsql_m_n;\n  vsql_m_sqlstate(SQLSTATE, "00000");\n')
	assert !m4.source.contains('  vsql_m_begin(')

	// Only the sections of the runtime that are used are included.
	m2 := compile_module(module_header + 'PROCEDURE p (SQLSTATE); DISCONNECT ALL;', 'm')!
	assert m2.source.contains('vsql_m_disconnect(')
	assert !m2.source.contains('vsql_m_execute(')
	assert !m2.source.contains('vsql_m_switch(')

	// The schema is the authorization identifier when there's no SCHEMA.
	m3 := compile_module('MODULE m LANGUAGE C AUTHORIZATION bob PROCEDURE p (SQLSTATE); COMMIT;',
		'm')!
	assert m3.source.contains('"SET SCHEMA \'BOB\'"')
}

// 9.2 Store assignment, GR 3.a.ii: on a store only -1 is the null value, and an
// indicator less than -1 is 22010. Everywhere else, any negative indicator is
// the null value (6.4, GR 4).
fn test_module_store_indicator() ! {
	stored := fn (ind string) string {
		return '  if (*${ind} < -1) {\n    vsql_m_status(SQLSTATE, "22010");\n    return;\n  }\n'
	}
	m := compile_module(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :o :c;
PROCEDURE ins (SQLSTATE, :a INT, :b INT, :e INT, :f INT, :g INT, :h INT, :i SMALLINT, :j SMALLINT, :k SMALLINT, :l SMALLINT, :m SMALLINT, :n SMALLINT);
  INSERT INTO t (a, b, c, d, e) VALUES (:a :i, :b INDICATOR :j, DEFAULT, NULL, (:e :k)), (1, :f, CAST(:g :l AS INT), :h :m + 1, (:h :n));
PROCEDURE ins1 (SQLSTATE, :a INT, :i SMALLINT); INSERT INTO t (a) VALUES (:a :i);
PROCEDURE ins2 (SQLSTATE, :a BOOLEAN, :i SMALLINT); INSERT INTO t (a) VALUES :a :i;
PROCEDURE ins3 (SQLSTATE); INSERT INTO t (a) VALUES (NULL);
PROCEDURE ins4 (SQLSTATE, :a INT, :i SMALLINT); INSERT INTO t (a) VALUES :a :i + 1;
PROCEDURE ins5 (SQLSTATE, :a INT, :i SMALLINT); INSERT INTO t (a) VALUES (1 = :a :i);
PROCEDURE upd (SQLSTATE, :a INT, :b INT, :c INT, :d INT, :e INT, :i SMALLINT, :j SMALLINT, :k SMALLINT, :l SMALLINT, :m SMALLINT);
  UPDATE t SET a = :a :i, b = DEFAULT, c = (:b :j), d = :c :k * 2 WHERE e = :d :l AND f = (SELECT MAX(x) FROM u WHERE y = :e :m);
PROCEDURE pos (SQLSTATE, :a INT, :i SMALLINT); UPDATE t SET a = :a :i WHERE CURRENT OF c;
PROCEDURE del (SQLSTATE, :a INT, :i SMALLINT); DELETE FROM t WHERE a = :a :i;
PROCEDURE sel (SQLSTATE, :a INT, :b INT, :i SMALLINT); SELECT x INTO :b FROM t WHERE a = :a :i;
PROCEDURE opn (SQLSTATE, :o INT, :c SMALLINT); OPEN c;
PROCEDURE ex (SQLSTATE, :a INT, :i SMALLINT, :s VARCHAR(10)); PREPARE s FROM :s;
PROCEDURE ex2 (SQLSTATE, :a INT, :i SMALLINT); EXECUTE s USING :a :i;
', 'm')!
	body := fn [m] (name string) string {
		return m.source.all_after('void ${name}(').all_before('\n}\n')
	}

	// A host parameter that is a whole value, including in parentheses.
	for ind in ['i', 'j', 'k', 'n'] {
		assert body('ins').contains(stored(ind))
	}
	assert body('ins1').contains(stored('i'))
	assert body('ins2').contains(stored('i'))
	assert body('upd').contains(stored('i'))
	assert body('upd').contains(stored('j'))
	assert body('pos').contains(stored('i'))

	// The check comes before the value becomes the null value.
	assert body('ins1').contains('${stored('i')}  if (*i < 0) {\n    vsql_m_p[0].indicator = SQL_NULL_DATA;\n  }\n')

	// A host parameter that is only part of a value, or isn't stored at all.
	for ind in ['l', 'm'] {
		assert !body('ins').contains(stored(ind))
		assert body('ins').contains('if (*${ind} < 0) {')
	}
	for ind in ['k', 'l', 'm'] {
		assert !body('upd').contains(stored(ind))
		assert body('upd').contains('if (*${ind} < 0) {')
	}
	for name in ['ins4', 'ins5', 'del', 'sel', 'ex2'] {
		assert !body(name).contains('22010')
		assert body(name).contains('if (*i < 0) {')
	}
	assert !body('opn').contains('22010')
	assert body('opn').contains('if (*c < 0) {')
	assert !body('ins3').contains('22010')

	// An indicator variable of embedded SQL is the same, because it's an
	// indicator parameter of the implied module.
	p := precompile_c('EXEC SQL BEGIN DECLARE SECTION;
char SQLSTATE[6]; long x; short i;
EXEC SQL END DECLARE SECTION;
int main(void) {
  EXEC SQL INSERT INTO t (a) VALUES (:x :i);
  EXEC SQL DELETE FROM t WHERE a = :x INDICATOR :i;
  return 0;
}
', 'x.sqc')!
	assert p.source.all_after('void vsql_e1(').all_before('\n}\n').contains(stored('i'))
	assert !p.source.all_after('void vsql_e2(').all_before('\n}\n').contains('22010')
}

fn test_module_errors() ! {
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE);') == 'syntax error: a module must end with a procedure that has a statement'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); COMMIT; PROCEDURE P (SQLSTATE); COMMIT;') == 'syntax error: procedure P is defined more than once'
	assert module_error('MODULE LANGUAGE ADA SCHEMA s PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: only LANGUAGE C is supported, not ADA'
	assert module_error('MODULE LANGUAGE C PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: expected SCHEMA or AUTHORIZATION after LANGUAGE C'
	assert module_error(module_header + 'PATH s PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: expected PROCEDURE or DECLARE after the module authorization clause'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); COMMIT') == 'syntax error: a statement in a module must end with a semicolon'
	assert module_error('MODULE') == 'syntax error: a statement in a module must end with a semicolon'
	assert module_error('MODULE;;') == 'syntax error: expected LANGUAGE at the end'
	assert module_error('LANGUAGE C;;') == 'syntax error: expected MODULE near LANGUAGE'
	assert module_error('MODULE LANGUAGE C SCHEMA 1;;') == 'syntax error: expected schema name near 1'
	assert module_error('MODULE LANGUAGE C SCHEMA "";;') == 'syntax error: invalid delimited identifier: ""'
	assert module_error('MODULE LANGUAGE C SCHEMA "s;;') == 'syntax error: unterminated delimited identifier: "s'
	assert compile_module('MODULE LANGUAGE C SCHEMA "a""b" PROCEDURE p (SQLSTATE); COMMIT;',
		'm')!.source.contains('SET SCHEMA \'a\\"b\'')
	assert module_error("MODULE LANGUAGE C SCHEMA 's;;") == "syntax error: unterminated string: 's;;"
	assert module_error(module_header + 'PROCEDURE "p" (SQLSTATE); COMMIT;') == 'syntax error: expected procedure name near p'
	assert module_error(module_header + 'PROCEDURE p SQLSTATE; COMMIT;') == 'syntax error: expected ( near SQLSTATE'

	// 13.3 <externally-invoked procedure>
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, SQLSTATE); COMMIT;') == 'syntax error: procedure p: SQLSTATE can only be used once'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a INT, :A INT); COMMIT;') == 'syntax error: procedure p: host parameter :A is declared more than once'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE) x; COMMIT;') == 'syntax error: procedure p: expected ; near x'
	assert module_error(module_header + 'PROCEDURE p (:a INT); COMMIT;') == 'syntax error: procedure p: SQLSTATE must be one of the parameters'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, a INT); COMMIT;') == 'syntax error: expected : near a'

	// 13.5 Data type correspondences
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a VARCHAR); COMMIT;') == 'syntax error: host parameter :a: CHARACTER VARYING must have a length'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a CHAR(0)); COMMIT;') == 'syntax error: expected a length near 0'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a DOUBLE); COMMIT;') == 'syntax error: expected PRECISION near )'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a DATE); COMMIT;') == 'syntax error: host parameter :a: the data type must be CHARACTER, CHARACTER VARYING, SMALLINT, INTEGER, BIGINT, REAL, DOUBLE PRECISION or BOOLEAN'

	// 13.4 <SQL procedure statement>
	assert module_error(module_header + "PROCEDURE p (SQLSTATE); VALUES 'a;") == "syntax error: unterminated string: 'a;"
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); VALUES "a;') == 'syntax error: unterminated delimited identifier: "a'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = ?;') == 'syntax error: procedure p: a module cannot contain a dynamic parameter (?), use a host parameter (:name)'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = "";') == 'syntax error: procedure p: a delimited identifier cannot be empty'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); VALUES 1;') == 'syntax error: procedure p: a query is not an SQL procedure statement, use SELECT ... INTO'
	parse_error := module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE t;')
	assert parse_error.starts_with('syntax error: procedure p: ')
	assert parse_error.count('syntax error') == 1
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = :x;') == 'syntax error: procedure p: host parameter :x is not declared'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DELETE FROM t WHERE x = : x;') == 'syntax error: expected a host parameter name after :'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :x INT); DELETE FROM t WHERE x = :x INDICATOR 1;') == 'syntax error: expected an indicator parameter after INDICATOR'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :x INT, :i REAL); DELETE FROM t WHERE x = :x :i;') == 'syntax error: procedure p: indicator parameter :i must be SMALLINT, INTEGER or BIGINT'

	// 14.7 <select statement: single row>
	select_header := module_header + 'PROCEDURE p (SQLSTATE, :a INT, :b REAL); '
	assert module_error(select_header + 'SELECT x INTO :a, :b FROM t;') == 'syntax error: procedure p: the select list has 1 column, but there are 2 targets'
	assert module_error(select_header + 'SELECT x, y INTO :a FROM t;') == 'syntax error: procedure p: the select list has 2 columns, but there is 1 target'
	assert module_error(select_header + 'SELECT x INTO a FROM t;') == 'syntax error: procedure p: expected a host parameter after INTO near a'
	assert module_error(select_header + 'SELECT x INTO FROM t;') == 'syntax error: procedure p: expected a host parameter after INTO at the end'
	assert module_error(select_header + 'SELECT x INTO :c FROM t;') == 'syntax error: procedure p: host parameter :c is not declared'
	assert module_error(select_header + 'SELECT x INTO :a :b FROM t;') == 'syntax error: procedure p: indicator parameter :b must be SMALLINT, INTEGER or BIGINT'
	assert module_error(select_header + 'SELECT x INTO :a INDICATOR b FROM t;') == 'syntax error: expected : near b'
	assert module_error(select_header + 'SELECT x INTO :a x FROM t;') == 'syntax error: procedure p: expected FROM near x'
	assert module_error(select_header + 'SELECT x INTO :a FROM t ORDER BY x;') == 'syntax error: procedure p: SELECT ... INTO cannot have UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH'
	assert module_error(select_header + 'SELECT x INTO :a FROM t UNION SELECT x FROM t;') == 'syntax error: procedure p: SELECT ... INTO cannot have UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH'
	assert module_error(select_header + 'SELECT x INTO :a FROM t FETCH FIRST 1 ROW ONLY;') == 'syntax error: procedure p: SELECT ... INTO cannot have UNION, EXCEPT, INTERSECT, ORDER BY, OFFSET or FETCH'
	assert module_error(select_header + 'SELECT x + INTO :a;').starts_with('syntax error: procedure p: ')
	assert module_error(select_header + 'SELECT 1 INTO :a;') == ''
	assert module_error(select_header + 'SELECT t.* INTO :a FROM t;') == ''
	assert module_error(select_header + 'SELECT * INTO :a FROM t;') == ''
	assert module_error(select_header + 'SELECT :b INTO :a FROM t;') == ''
	assert module_error(select_header + 'SELECT x FROM t;') == 'syntax error: procedure p: a query is not an SQL procedure statement, use SELECT ... INTO'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :a INT, :i SMALLINT); SELECT ("x") INTO :a INDICATOR :i FROM t;') == ''

	// 23.1 <get diagnostics statement>
	diag_header := module_header + 'PROCEDURE p (SQLSTATE, :n INT, :s CHAR(5), :r REAL); GET DIAGNOSTICS '
	assert module_error(diag_header + 'n = NUMBER;') == 'syntax error: procedure p: expected a host parameter near n'
	assert module_error(diag_header + ':x = NUMBER;') == 'syntax error: procedure p: host parameter :x is not declared'
	assert module_error(diag_header + ':n NUMBER;') == 'syntax error: expected = near NUMBER'
	assert module_error(diag_header + ':s = ALL;') == 'syntax error: procedure p: GET DIAGNOSTICS ... = ALL is not supported'
	assert module_error(diag_header + ':n = MESSAGE_TEXT;') == 'syntax error: procedure p: expected a statement information item name near MESSAGE_TEXT'
	assert module_error(diag_header + ':n =;') == 'syntax error: procedure p: expected a statement information item name at the end'
	assert module_error(diag_header + 'CONDITION 1 :n = NUMBER;') == 'syntax error: procedure p: expected a condition information item name near NUMBER'
	assert module_error(diag_header + ':s = NUMBER;') == 'syntax error: procedure p: host parameter :s must be SMALLINT, INTEGER or BIGINT for NUMBER'
	assert module_error(diag_header + ':r = MORE;') == 'syntax error: procedure p: host parameter :r must be CHARACTER or CHARACTER VARYING for MORE'
	assert module_error(diag_header + ':n = NUMBER x;') == 'syntax error: procedure p: unexpected near x'
	assert module_error(diag_header + 'CONDITION :r :n = CONDITION_NUMBER;') == 'syntax error: procedure p: the condition number :r must be SMALLINT, INTEGER or BIGINT'
	assert module_error(diag_header + 'CONDITION :x :n = CONDITION_NUMBER;') == 'syntax error: procedure p: host parameter :x is not declared'
	assert module_error(diag_header + 'CONDITION :n = CONDITION_NUMBER;') == 'syntax error: procedure p: expected a host parameter near ='
	assert module_error(diag_header + 'CONDITION x :n = CONDITION_NUMBER;') == 'syntax error: procedure p: expected a condition number near x'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); GET x;').starts_with('syntax error: procedure p: ')

	// 18 SQL-connection statements
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); CONNECT DEFAULT;') == 'syntax error: expected TO near DEFAULT'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :n INT); CONNECT TO :n;') == 'syntax error: procedure p: host parameter :n must be CHARACTER or CHARACTER VARYING'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); CONNECT TO 1;') == 'syntax error: procedure p: expected a string or a host parameter near 1'
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); DISCONNECT ALL x;') == 'syntax error: unexpected near x'
}

fn test_flagging_module() ! {
	for body, features in flagging_modules {
		m := compile_module(module_header + body, 'm')!
		assert m.features == unique_features(features, 'B112'), body
	}

	// The names of the module header.
	for header, features in {
		'MODULE module_name_17cha LANGUAGE C SCHEMA schema_name_17cha AUTHORIZATION a ': ['B112']
		'MODULE module_name_18char LANGUAGE C SCHEMA s ':                                [
			'B112',
			'F391',
		]
		'MODULE LANGUAGE C SCHEMA schema_name_18char ':                                  [
			'B112',
			'F391',
		]
		'MODULE LANGUAGE C AUTHORIZATION authorization_18ch ':                           [
			'B112',
			'F391',
		]
	} {
		assert compile_module(header + 'PROCEDURE p (SQLSTATE); COMMIT;', 'm')!.features == features, header
	}
}

fn test_flagging_embedded() ! {
	precompiled := fn (body string) ![]string {
		return precompile_c(embed_header + body, 'x.sqc')!.features
	}

	// A program needs its language (B012), but not the language of its implied
	// module (B112). The rules of the statements are the same as a module.
	assert precompiled('EXEC SQL COMMIT;')! == ['B012']
	assert precompiled('EXEC SQL DELETE FROM t WHERE x = CURRENT_SCHEMA;')! == ['B012', 'F763']
	assert precompiled('EXEC SQL CONNECT TO DEFAULT;')! == ['B012', 'F771']

	// long long needs T071, even if it isn't used.
	assert precompile_c('EXEC SQL BEGIN DECLARE SECTION;
char SQLSTATE[6]; long long a;
EXEC SQL END DECLARE SECTION;
EXEC SQL COMMIT;',
		'x.sqc')!.features == ['B012', 'T071']

	// A host variable is a <host identifier>, which isn't flagged with F391,
	// but a <statement name> is.
	assert precompile_c('EXEC SQL BEGIN DECLARE SECTION;
char SQLSTATE[6]; long host_variable_name_18c;
EXEC SQL END DECLARE SECTION;
EXEC SQL DELETE FROM t WHERE x = :host_variable_name_18c;',
		'x.sqc')!.features == ['B012']
	assert precompiled("EXEC SQL PREPARE statement_name_18c FROM 'VALUES 1';")! == [
		'B012',
		'B031',
		'F391',
		vsql_prepare_literal,
	]

	// The <SQL condition> of an <embedded exception declaration>.
	assert precompiled('EXEC SQL WHENEVER SQLEXCEPTION CONTINUE; EXEC SQL COMMIT;')! == ['B012']
	assert precompiled('EXEC SQL WHENEVER SQLSTATE (22) CONTINUE; EXEC SQL COMMIT;')! == [
		'B012',
		'B041',
	]
	assert precompiled('EXEC SQL WHENEVER CONSTRAINT c CONTINUE; EXEC SQL COMMIT;')! == [
		'B012',
		'B041',
		'F491',
	]
}

fn test_flagging_direct() ! {
	// Direct SQL itself, and whatever else the statement uses. It's only parsed.
	assert direct_features('COMMIT;')! == ['B021']
	assert direct_features('SELECT * FROM does_not_exist;')! == ['B021']
	assert direct_features('SELECT CURRENT_SCHEMA FROM t;')! == ['B021', 'F763']
	assert 'B021' in direct_features('CONNECT TO DEFAULT;')!

	// The same errors as Connection.direct.
	for stmt in ['VALUES 1', 'VALUES 1; VALUES 2;', 'VALUES ?;', 'VALUES :x;'] {
		direct_features(stmt) or {
			assert err.code() == sqlstate_to_int('42601')
			continue
		}
		assert false, stmt
	}
}

// 14.1 <declare cursor> in a module, with OPEN, FETCH, CLOSE and positioned
// statements in its procedures.
fn test_module_cursors() ! {
	m := compile_module(module_header + 'DECLARE "c" /* FOR */ CURSOR WITH HOLD FOR SELECT x, y FROM t WHERE x > :min;
PROCEDURE o (SQLSTATE, :min INTEGER); OPEN "c";
DECLARE d CURSOR FOR SELECT * FROM t;
PROCEDURE o2 (SQLSTATE); OPEN d;
PROCEDURE f (SQLSTATE, :x INTEGER, :y VARCHAR(5), :i SMALLINT); FETCH NEXT FROM "c" INTO :x, :y INDICATOR :i;
PROCEDURE f2 (SQLSTATE, :x INTEGER); FETCH FROM d INTO :x;
PROCEDURE f3 (SQLSTATE, :x INTEGER, :y INTEGER); FETCH "c" INTO :x, :y;
PROCEDURE cl (SQLSTATE); CLOSE "c";
PROCEDURE del (SQLSTATE); DELETE FROM t WHERE CURRENT OF "c";
PROCEDURE upd (SQLSTATE, :y VARCHAR(5)); UPDATE t SET y = :y WHERE CURRENT OF "c";
PROCEDURE del2 (SQLSTATE); DELETE FROM t AS u WHERE CURRENT OF "c";
PROCEDURE upd2 (SQLSTATE); UPDATE t AS u SET y = u.y WHERE CURRENT OF "c";',
		'm')!
	assert m.source.contains('static const int vsql_m_cursor_count = 2;')
	assert m.source.contains('  vsql_m_begin("OPEN", 53);\n  vsql_m_da.cursor_name = "c";\n  struct vsql_m_param vsql_m_p[1] = {\n')
	assert m.source.contains('  vsql_m_open_cursor(SQLSTATE, 0, "\\"c\\"", 1, "SELECT x, y FROM t WHERE x > CAST(? AS INTEGER)", 1, vsql_m_p);\n')
	assert m.source.contains('  vsql_m_begin("FETCH", 45);\n  vsql_m_da.cursor_name = "c";\n  struct vsql_m_target vsql_m_t[2] = {\n')
	assert m.source.contains('  if (vsql_m_fetch(SQLSTATE, 0, 2, vsql_m_t)) {\n    *i = (short)vsql_m_t[1].indicator;\n  }\n')
	assert m.source.contains('  vsql_m_fetch(SQLSTATE, 1, 1, vsql_m_t);\n')
	assert m.source.contains('  vsql_m_begin("CLOSE CURSOR", 9);\n  vsql_m_da.cursor_name = "c";\n  vsql_m_close_cursor(SQLSTATE, 0);\n')
	assert m.source.contains('  vsql_m_begin("DELETE CURSOR", 18);\n  vsql_m_da.cursor_name = "c";\n  vsql_m_execute(SQLSTATE, "DELETE FROM t WHERE CURRENT OF \\"c\\"", 0, NULL);\n')
	assert m.source.contains('  vsql_m_begin("UPDATE CURSOR", 81);\n')
	assert m.source.contains('  vsql_m_begin("DELETE CURSOR", 18);\n  vsql_m_da.cursor_name = "c";\n  vsql_m_execute(SQLSTATE, "DELETE FROM t AS u WHERE CURRENT OF \\"c\\"", 0, NULL);\n')
	assert m.source.contains('  vsql_m_begin("UPDATE CURSOR", 81);\n  vsql_m_da.cursor_name = "c";\n  vsql_m_execute(SQLSTATE, "UPDATE t AS u SET y = u.y WHERE CURRENT OF \\"c\\"", 0, NULL);\n')

	// The cursors aren't in a module that doesn't have any. The SQL-connections
	// still have a list of the cursors of each module, since they're shared with
	// other modules that may have cursors.
	m2 := compile_module(module_header + 'PROCEDURE p (SQLSTATE); COMMIT;', 'm')!
	assert !m2.source.contains('vsql_m_cursor_count')

	cursor_header := module_header + 'DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE p (SQLSTATE, :x INTEGER); '
	assert module_error(cursor_header + 'FETCH c INTO :x, :x;') == 'syntax error: procedure p: cursor C has 1 column, but there are 2 targets'
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x, y FROM t; PROCEDURE p (SQLSTATE, :x INTEGER); FETCH c INTO :x;') == 'syntax error: procedure p: cursor C has 2 columns, but there is 1 target'
	assert module_error(cursor_header + 'FETCH NEXT c INTO :x;') == 'syntax error: expected FROM near c'
	assert module_error(cursor_header + 'FETCH c :x;') == 'syntax error: expected INTO near :'
	assert module_error(cursor_header + 'FETCH c INTO :x x;') == 'syntax error: procedure p: unexpected near x'
	assert module_error(cursor_header + 'OPEN d;') == 'syntax error: procedure p: cursor D must be declared before it is used'
	assert module_error(cursor_header + 'CLOSE c c;') == 'syntax error: procedure p: unexpected near c'
	assert module_error(cursor_header + 'OPEN c c;') == 'syntax error: procedure p: unexpected near c'
	assert module_error(cursor_header + 'DELETE FROM t WHERE CURRENT OF d;') == 'syntax error: procedure p: cursor D must be declared before it is used'
	assert module_error(cursor_header + 'UPDATE t SET x = 1 WHERE CURRENT OF d;') == 'syntax error: procedure p: cursor D must be declared before it is used'
	assert module_error(cursor_header + 'DECLARE d CURSOR FOR VALUES 1;') == 'syntax error: procedure p: a cursor must be declared in the module, not in a procedure'
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :y; PROCEDURE p (SQLSTATE); OPEN c;') == 'syntax error: procedure p: host parameter :y is not declared'
	assert module_error(cursor_header + 'COMMIT; DECLARE C CURSOR FOR VALUES 2;') == 'syntax error: cursor C is declared more than once'
	assert module_error(module_header + 'DECLARE c CURSOR FOR VALUES ?; PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: a module cannot contain a dynamic parameter (?), use a host parameter (:name)'
	// The <updatability clause> is part of the query that OPEN executes (see
	// PreparedStmt.open_cursor).
	updatable := compile_module(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t FOR UPDATE OF x; PROCEDURE p (SQLSTATE); OPEN c;',
		'm')!
	assert updatable.source.contains(', "SELECT x FROM t FOR UPDATE OF x", 0, ')
	assert module_error(module_header + 'PROCEDURE p (SQLSTATE); COMMIT; DECLARE c CURSOR FOR VALUES 1; PROCEDURE q (SQLSTATE);') == 'syntax error: a module must end with a procedure that has a statement'
	assert module_error(module_header + 'DECLARE c CURSOR VALUES 1; PROCEDURE p (SQLSTATE); COMMIT;').starts_with('syntax error')

	// A cursor is declared before each procedure that references it, even in
	// the procedure that follows the declaration of another cursor.
	declared_after := ' DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE q (SQLSTATE); OPEN c;'
	for stmt in ['OPEN c', 'FETCH c INTO :x', 'CLOSE c', 'DELETE FROM t WHERE CURRENT OF c',
		'UPDATE t SET x = 1 WHERE CURRENT OF c'] {
		assert module_error(module_header + 'PROCEDURE p (SQLSTATE, :x INTEGER); ${stmt};' +
			declared_after) == 'syntax error: procedure p: cursor C must be declared before it is used', stmt
	}

	// There's exactly one OPEN of each cursor, with any name that identifies it.
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE p (SQLSTATE); CLOSE c;') == 'syntax error: cursor C must be opened by exactly one procedure, not 0'
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE p (SQLSTATE); COMMIT;') == 'syntax error: cursor C must be opened by exactly one procedure, not 0'
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t; PROCEDURE p (SQLSTATE); OPEN c; PROCEDURE q (SQLSTATE); OPEN "C";') == 'syntax error: cursor C must be opened by exactly one procedure, not 2'
	assert module_error(module_header + 'DECLARE c CURSOR FOR SELECT x FROM t; DECLARE d CURSOR FOR SELECT x FROM t; PROCEDURE p (SQLSTATE); OPEN c;') == 'syntax error: cursor D must be opened by exactly one procedure, not 0'

	// "c" isn't C, so each has its own OPEN.
	compile_module(module_header + 'DECLARE c CURSOR FOR VALUES 1; DECLARE "c" CURSOR FOR VALUES 2; PROCEDURE p (SQLSTATE); OPEN C; PROCEDURE q (SQLSTATE); OPEN "c";',
		'm')!
}

// Feature B031, "Basic dynamic SQL".
fn test_module_dynamic_sql() ! {
	m := compile_module(module_header +
		'PROCEDURE h (SQLSTATE, :n INTEGER, :s VARCHAR(5)); GET DESCRIPTOR d :n = COUNT, :n = TOP_LEVEL_COUNT, :n = KEY_TYPE, :s = DYNAMIC_FUNCTION, :n = DYNAMIC_FUNCTION_CODE;
PROCEDURE g (SQLSTATE, :n INTEGER, :s VARCHAR(5), :c CHAR(3)); GET SQL DESCRIPTOR GLOBAL \' g \' VALUE :n :s = DATA, :n = INDICATOR, :c = NAME, :n = TYPE;
PROCEDURE g2 (SQLSTATE, :n INTEGER); GET DESCRIPTOR LOCAL \'g\' VALUE 2 :n = DATA;
PROCEDURE a (SQLSTATE, :n SMALLINT); ALLOCATE SQL DESCRIPTOR d WITH MAX :n;
PROCEDURE a2 (SQLSTATE); ALLOCATE DESCRIPTOR "d";
PROCEDURE de (SQLSTATE); DEALLOCATE SQL DESCRIPTOR d;
PROCEDURE sc (SQLSTATE); SET DESCRIPTOR d COUNT = -1;
PROCEDURE sv (SQLSTATE, :s VARCHAR(5)); SET DESCRIPTOR d VALUE 2 DATA = :s, CHARACTER_SET_NAME = :s, SCOPE_NAME = \'x\', LENGTH = 5, TYPE = 12, LEVEL = 0;
PROCEDURE sb (SQLSTATE, :b BOOLEAN); SET DESCRIPTOR d VALUE 1 DATA = :b;
PROCEDURE pr (SQLSTATE, :s VARCHAR(5)); PREPARE s FROM :s;
PROCEDURE pr2 (SQLSTATE); PREPARE s FROM \'SELECT 1\';
PROCEDURE dp (SQLSTATE); DEALLOCATE PREPARE s;
PROCEDURE ds (SQLSTATE); DESCRIBE s USING DESCRIPTOR d WITH NESTING;
PROCEDURE ds2 (SQLSTATE); DESCRIBE OUTPUT s USING SQL DESCRIPTOR d WITHOUT NESTING;
PROCEDURE ex (SQLSTATE); EXECUTE s;
PROCEDURE ex2 (SQLSTATE, :n INTEGER, :s VARCHAR(5), :i INTEGER); EXECUTE s INTO :n, :s INDICATOR :i USING :s :i, :n;
PROCEDURE ex3 (SQLSTATE); EXECUTE s INTO DESCRIPTOR d USING DESCRIPTOR GLOBAL \'g\';
PROCEDURE ei (SQLSTATE); EXECUTE IMMEDIATE \'DELETE FROM t\';
DECLARE c0 CURSOR FOR SELECT 1 FROM t;
PROCEDURE o0 (SQLSTATE); OPEN c0;
DECLARE dc CURSOR WITH HOLD FOR s;
PROCEDURE o (SQLSTATE); OPEN dc;
PROCEDURE o2 (SQLSTATE, :n INTEGER); OPEN dc USING :n;
PROCEDURE f (SQLSTATE, :n INTEGER); FETCH NEXT FROM dc INTO :n;
PROCEDURE f2 (SQLSTATE); FETCH dc INTO SQL DESCRIPTOR d;
PROCEDURE cl (SQLSTATE); CLOSE dc;
PROCEDURE dl (SQLSTATE); DELETE FROM t WHERE CURRENT OF dc;
PROCEDURE up (SQLSTATE); UPDATE t SET x = 1 WHERE CURRENT OF dc;',
		'm')!
	assert m.source.contains('static const char *const vsql_m_cursor_statements[] = {NULL, "S", NULL};\n')
	assert m.source.contains('  int vsql_m_w = 0;\n  vsql_m_begin("GET DESCRIPTOR", 47);\n  struct vsql_m_descriptor *vsql_m_d = vsql_m_descriptor(SQLSTATE, "D", &vsql_m_own);\n')
	assert m.source.contains('  *n = (long)vsql_m_d->count;\n  *n = (long)vsql_m_d->top_level_count;\n  *n = (long)vsql_m_d->key_type;\n  vsql_m_w |= vsql_m_put(s, 5, vsql_m_d->dynamic_function);\n  *n = (long)vsql_m_d->dynamic_function_code;\n')
	assert m.source.contains('  struct vsql_m_item *vsql_m_i = vsql_m_get_item(SQLSTATE, "G", NULL, (long long)*n, SQL_VARCHAR, 5, 1);\n')
	assert m.source.contains('  vsql_m_w |= vsql_m_get_data(vsql_m_i, s, SQL_VARCHAR, 5);\n  *n = (long)vsql_m_i->number[VSQL_M_INDICATOR];\n  vsql_m_w |= vsql_m_put(c, 3, vsql_m_i->string[VSQL_M_NAME] == NULL ? "" : vsql_m_i->string[VSQL_M_NAME]);\n')
	assert m.source.contains('vsql_m_get_item(SQLSTATE, "G", &vsql_m_own, 2LL, SQL_INTEGER, 0, 0);\n')
	assert m.source.contains('  vsql_m_allocate_descriptor(SQLSTATE, "D", &vsql_m_own, (long long)*n);\n')
	assert m.source.contains('  vsql_m_allocate_descriptor(SQLSTATE, "d", &vsql_m_own, 100LL);\n')
	assert m.source.contains('  vsql_m_begin("DEALLOCATE DESCRIPTOR", 15);\n  vsql_m_deallocate_descriptor(SQLSTATE, "D", &vsql_m_own);\n')
	assert m.source.contains('  vsql_m_set_count(SQLSTATE, "D", &vsql_m_own, -1LL);\n')

	// - 20.5 GR 4. The components are set in a fixed order.
	assert m.source.contains('  if (vsql_m_i != NULL &&\n      vsql_m_set_number(SQLSTATE, vsql_m_i, VSQL_M_LEVEL, 0LL) &&\n      vsql_m_set_number(SQLSTATE, vsql_m_i, VSQL_M_TYPE, 12LL) &&\n      vsql_m_set_string(vsql_m_i, VSQL_M_CHARACTER_SET_NAME, s) &&\n      vsql_m_set_string(vsql_m_i, VSQL_M_SCOPE_NAME, "x") &&\n      vsql_m_set_number(SQLSTATE, vsql_m_i, VSQL_M_LENGTH, 5LL) &&\n      vsql_m_set_data(SQLSTATE, vsql_m_i, SQL_VARCHAR, 5, s)) {\n')
	assert m.source.contains('      vsql_m_set_data(SQLSTATE, vsql_m_i, SQL_BOOLEAN, 0, b)) {\n')
	assert m.source.contains('  vsql_m_begin("PREPARE", 56);\n  if (!vsql_m_string(SQLSTATE, s, 24)) {\n    return;\n  }\n  vsql_m_prepare(SQLSTATE, "S", s);\n')
	assert m.source.contains('  vsql_m_prepare(SQLSTATE, "S", "SELECT 1");\n')
	assert m.source.contains('  vsql_m_begin("DEALLOCATE PREPARE", 16);\n  vsql_m_deallocate_prepare(SQLSTATE, "S");\n')
	assert m.source.contains('  vsql_m_begin("DESCRIBE", 20);\n  vsql_m_describe(SQLSTATE, "S", "D", &vsql_m_own);\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {-1, NULL, NULL, NULL};\n  struct vsql_m_output vsql_m_out = {-1, NULL, NULL, NULL};\n  vsql_m_execute_prepared(SQLSTATE, "S", &vsql_m_in, &vsql_m_out);\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {2, vsql_m_p, NULL, NULL};\n  struct vsql_m_target vsql_m_t[2] = {\n')
	assert m.source.contains('  struct vsql_m_output vsql_m_out = {2, vsql_m_t, NULL, NULL};\n  if (vsql_m_execute_prepared(SQLSTATE, "S", &vsql_m_in, &vsql_m_out)) {\n    *i = (long)vsql_m_t[1].indicator;\n  }\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {0, NULL, "G", NULL};\n  struct vsql_m_output vsql_m_out = {0, NULL, "D", &vsql_m_own};\n')
	assert m.source.contains('  vsql_m_begin("EXECUTE IMMEDIATE", 43);\n  vsql_m_execute_immediate(SQLSTATE, "DELETE FROM t");\n')
	assert m.source.contains('  vsql_m_begin("DYNAMIC OPEN", 40);\n  vsql_m_da.cursor_name = "DC";\n  struct vsql_m_input vsql_m_in = {-1, NULL, NULL, NULL};\n  vsql_m_open_dynamic(SQLSTATE, 1, "\\"DC\\"", 1, "S", &vsql_m_in);\n')
	assert m.source.contains('  struct vsql_m_input vsql_m_in = {1, vsql_m_p, NULL, NULL};\n  vsql_m_open_dynamic(')
	assert m.source.contains('  vsql_m_begin("DYNAMIC FETCH", 39);\n  vsql_m_da.cursor_name = "DC";\n  struct vsql_m_target vsql_m_t[1] = {\n')
	assert m.source.contains('  vsql_m_fetch_dynamic(SQLSTATE, 1, &vsql_m_out);\n')
	assert m.source.contains('  struct vsql_m_output vsql_m_out = {0, NULL, "D", &vsql_m_own};\n  vsql_m_fetch_dynamic(')
	assert m.source.contains('  vsql_m_begin("DYNAMIC CLOSE", 37);\n')
	assert m.source.contains('  vsql_m_begin("DYNAMIC DELETE CURSOR", 38);\n')
	assert m.source.contains('  vsql_m_begin("DYNAMIC UPDATE CURSOR", 42);\n')

	h := module_header +
		'PROCEDURE p (SQLSTATE, :n INTEGER, :s VARCHAR(5), :r REAL); '
	prepared := " PROCEDURE q (SQLSTATE); PREPARE s FROM 'x';"
	for stmt, expected in {
		"ALLOCATE DESCRIPTOR '1 x';":                   "procedure p: '1 x' is not a valid descriptor name"
		'ALLOCATE DESCRIPTOR GLOBAL d;':                'procedure p: a descriptor name must be an identifier or a literal near d'
		'ALLOCATE DESCRIPTOR :s;':                      'procedure p: a descriptor name must be an identifier or a literal near s'
		'ALLOCATE x;':                                  'procedure p: expected DESCRIPTOR near x'
		'ALLOCATE DESCRIPTOR d WITH x;':                'expected MAX near x'
		'ALLOCATE DESCRIPTOR d WITH MAX :r;':           'procedure p: the number of occurrences :r must be SMALLINT, INTEGER or BIGINT'
		'ALLOCATE DESCRIPTOR d WITH MAX x;':            'procedure p: expected a number of occurrences near x'
		'ALLOCATE DESCRIPTOR d x;':                     'procedure p: unexpected near x'
		'GET DESCRIPTOR d :n = X;':                     'procedure p: expected a header item name near X'
		'GET DESCRIPTOR d VALUE 1 :n = X;':             'procedure p: expected a descriptor item name near X'
		'GET DESCRIPTOR d VALUE 1 n = TYPE;':           'procedure p: expected a host parameter near n'
		'GET DESCRIPTOR d VALUE 1 :s = TYPE;':          'procedure p: host parameter :s must be SMALLINT, INTEGER or BIGINT for TYPE'
		'GET DESCRIPTOR d VALUE 1 :n = NAME;':          'procedure p: host parameter :n must be CHARACTER or CHARACTER VARYING for NAME'
		'GET DESCRIPTOR d :s = COUNT;':                 'procedure p: host parameter :s must be SMALLINT, INTEGER or BIGINT for COUNT'
		'SET DESCRIPTOR d x = 1;':                      'expected COUNT near x'
		'SET DESCRIPTOR d VALUE 1 NAME = :s;':          'procedure p: NAME cannot be set'
		'SET DESCRIPTOR d VALUE 1 TYPE = 1, TYPE = 2;': 'procedure p: TYPE is set more than once'
		"SET DESCRIPTOR d VALUE 1 DATA = 'x';":         'procedure p: DATA must be set to a host parameter near x'
		'SET DESCRIPTOR d VALUE 1 TYPE = -:n;':         'procedure p: expected a value near :'
		'SET DESCRIPTOR d VALUE 1 TYPE = 1 x;':         'procedure p: unexpected near x'
		'PREPARE s :s;':                                'expected FROM near :'
		'PREPARE s FROM :s x;':                         'procedure p: unexpected near x'
		'DEALLOCATE PREPARE x;':                        'procedure p: statement X is not prepared in the module'
		'DEALLOCATE x;':                                'procedure p: expected DESCRIPTOR near x'
		'DESCRIBE INPUT s USING DESCRIPTOR d;':         'procedure p: DESCRIBE INPUT is not supported'
		'DESCRIBE s d;':                                'expected USING near d'
		'DESCRIBE s USING DESCRIPTOR d WITH x;':        'expected NESTING near x'
		'EXECUTE x;':                                   'procedure p: statement X is not prepared in the module'
		'EXECUTE s USING SQL x;':                       'expected DESCRIPTOR near x'
		'EXECUTE s INTO :x;':                           'procedure p: host parameter :x is not declared'
		'EXECUTE s USING :n x;':                        'procedure p: unexpected near x'
		'EXECUTE IMMEDIATE :s x;':                      'procedure p: unexpected near x'
		'SET SQL x;':                                   'expected DESCRIPTOR near x'
		'DELETE FROM "";':                              'procedure p: a delimited identifier cannot be empty'
		'COMMIT; DECLARE dc CURSOR FOR x;':             'cursor DC: statement X is not prepared in the module'
		'COMMIT; DECLARE dc CURSOR FOR 1;':             'expected statement name near 1'
		'OPEN dc; DECLARE dc CURSOR FOR s;':            'procedure p: cursor DC must be declared before it is used'
		'FETCH dc INTO :n; DECLARE dc CURSOR FOR s;':   'procedure p: cursor DC must be declared before it is used'
	} {
		assert module_error(h + stmt + prepared) == 'syntax error: ${expected}', stmt
	}
	assert module_error(h + "PREPARE 1 FROM 'x';") == 'syntax error: expected statement name near 1'
	assert module_error(h + 'COMMIT; DECLARE dc CURSOR FOR s; PROCEDURE f (SQLSTATE, :n INTEGER); FETCH dc :n;' +
		prepared) == 'syntax error: expected INTO near :'

	// A dynamic cursor doesn't have to be opened, and can be opened more than
	// once. Its statement can be prepared after it.
	compile_module(module_header + "DECLARE dc CURSOR FOR s; PROCEDURE p (SQLSTATE); PREPARE s FROM 'x';",
		'm')!
}

fn embed_error(source string) string {
	precompile_c(source, 'x.sqc') or { return err.msg() }
	return ''
}

const embed_header = 'EXEC SQL BEGIN DECLARE SECTION;
char SQLSTATE[6]; long a, b = 2; char c[11];
EXEC SQL END DECLARE SECTION;
'

fn test_embed_precompile() ! {
	p := precompile_c('// EXEC SQL is not in a comment
/* EXEC SQL */ #include <stdio.h>
int main(void) {
  char *s = "EXEC SQL \\" x"; char q = \'"\';
  EXEC  SQL BEGIN DECLARE SECTION;
  char SQLSTATE[6]; // the SQLSTATE
  static const long long a = 1, b; /* two */ short d; float e;
  double f = 1.5; varchar g[ 5 ] = "a,[\\"b", h[3] = {\'x\', 0};
  EXEC SQL END DECLARE SECTION;
  EXEC SQL WHENEVER SQLEXCEPTION GO TO failed;
  EXEC SQL WHENEVER SQLWARNING GOTO warned;
  EXEC SQL WHENEVER NOT FOUND GOTO done;
  exec sql insert into "t;" (x) values (\'a;\', :a, :g INDICATOR :d, :e, :f -- ;
    , :h, :a);
  EXEC SQL DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :b;
  EXEC SQL WHENEVER SQLEXCEPTION CONTINUE;
  EXEC SQL OPEN c;
failed: warned: done: return 0;
}
EXECUTE SQL x; MYEXEC SQL; EXEC SQLX; EXEC', 'x.sqc')!
	assert p.implied_module == 'MODULE LANGUAGE C SCHEMA "PUBLIC"
PROCEDURE vsql_e1 (SQLSTATE, :a BIGINT, :g CHARACTER VARYING(4), :d SMALLINT, :e REAL, :f DOUBLE PRECISION, :h CHARACTER VARYING(2));
  insert into "t;" (x) values (\'a;\', :a, :g INDICATOR :d, :e, :f -- ;
    , :h, :a);
DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :b;
PROCEDURE vsql_e2 (SQLSTATE, :b BIGINT);
  OPEN "C";
'
	assert p.source.contains('static void vsql_e1(char SQLSTATE[6], long long *a, char g[20], short *d, float *e, double *f, char h[12]) {')
	assert p.source.contains('#line 1 "x.sqc"\n// EXEC SQL is not in a comment\n')
	assert p.source.contains('  \n  char SQLSTATE[6]; // the SQLSTATE\n')
	assert p.source.contains('double f = 1.5; char g[20] = "a,[\\"b", h[12] = {\'x\', 0};\n')
	assert p.source.contains("  { vsql_e1(SQLSTATE, &a, g, &d, &e, &f, h); if (SQLSTATE[0] != '0' || SQLSTATE[1] > '2') goto failed; if (SQLSTATE[0] == '0' && SQLSTATE[1] == '1') goto warned; if (SQLSTATE[0] == '0' && SQLSTATE[1] == '2') goto done; }\n\n")
	assert p.source.contains("  { vsql_e2(SQLSTATE, &b); if (SQLSTATE[0] == '0' && SQLSTATE[1] == '1') goto warned; if (SQLSTATE[0] == '0' && SQLSTATE[1] == '2') goto done; }\nfailed:")
	assert !p.source.contains('#include "x.h"')
	assert !p.source.contains('vsql_m_violated')
}

// 21.1 <embedded SQL host program>, SR 22.h and 22.l.ii: the implied module has
// one procedure that opens a <declare cursor>, which is called by each OPEN. It
// isn't defined in the C if it's not called, since it would be a warning. A
// dynamic cursor has a procedure for each OPEN.
fn test_embed_cursor_opens() ! {
	// Opened twice, with the exception actions of each OPEN.
	p := precompile_c(embed_header + 'EXEC SQL DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :a AND y = :b;
EXEC SQL OPEN c;
EXEC SQL COMMIT;
EXEC SQL WHENEVER SQLEXCEPTION GOTO failed;
EXEC SQL OPEN C;
failed: return 0;
',
		'x.sqc')!
	assert p.implied_module == 'MODULE LANGUAGE C SCHEMA "PUBLIC"
DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :a AND y = :b;
PROCEDURE vsql_e1 (SQLSTATE, :a INTEGER, :b INTEGER);
  OPEN "C";
PROCEDURE vsql_e2 (SQLSTATE);
  COMMIT;
'
	assert p.source.contains('{ vsql_e1(SQLSTATE, &a, &b); }\n{ vsql_e2(SQLSTATE); }\n')
	assert p.source.contains("{ vsql_e1(SQLSTATE, &a, &b); if (SQLSTATE[0] != '0' || SQLSTATE[1] > '2') goto failed; }")

	// Not opened: the procedure is in the implied module, but not the C.
	p2 := precompile_c(embed_header + 'EXEC SQL DECLARE c CURSOR FOR SELECT x FROM t WHERE x = :a;
EXEC SQL DECLARE d CURSOR FOR SELECT x FROM t;
EXEC SQL OPEN d;
EXEC SQL FETCH c INTO :b;
',
		'x.sqc')!
	assert p2.implied_module.contains('PROCEDURE vsql_e1 (SQLSTATE, :a INTEGER);\n  OPEN "C";\n')
	assert !p2.source.contains('vsql_e1')
	assert p2.source.contains('static const int vsql_m_cursor_count = 2;')
	assert p2.source.contains('{ vsql_e2(SQLSTATE); }\n{ vsql_e3(SQLSTATE, &b); }\n')

	// A dynamic cursor.
	p3 := precompile_c(embed_header + "EXEC SQL PREPARE s FROM 'SELECT 1 WHERE 1 = ?';
EXEC SQL DECLARE dc CURSOR FOR s;
EXEC SQL OPEN dc USING :a;
EXEC SQL OPEN dc USING :b;
", 'x.sqc')!
	assert p3.implied_module.contains('PROCEDURE vsql_e2 (SQLSTATE, :a INTEGER);\n  OPEN dc USING :a;\n')
	assert p3.implied_module.contains('PROCEDURE vsql_e3 (SQLSTATE, :b INTEGER);\n  OPEN dc USING :b;\n')

	// A cursor is declared before any statement that references it.
	assert embed_error(embed_header + 'EXEC SQL FETCH c INTO :a;
EXEC SQL DECLARE c CURSOR FOR SELECT x FROM t;
EXEC SQL OPEN c;') == 'syntax error: line 4: cursor C must be declared before it is used'
	assert embed_error(embed_header + "EXEC SQL CLOSE dc;
EXEC SQL DECLARE dc CURSOR FOR s;
EXEC SQL PREPARE s FROM 'x';") == 'syntax error: line 4: cursor DC must be declared before it is used'

	// The host variables of the OPEN of a <declare cursor> are the ones in the
	// cursor, and USING is for a dynamic cursor.
	assert embed_error(embed_header + 'EXEC SQL DECLARE c CURSOR FOR VALUES 1;
EXEC SQL OPEN c USING :a;') == 'syntax error: line 5: unexpected near USING'
	assert embed_error(embed_header + 'EXEC SQL DECLARE c CURSOR FOR VALUES 1; EXEC SQL OPEN c c;') == 'syntax error: line 4: unexpected near c'

	// A cursor that's not opened isn't an SQL statement for the C.
	assert embed_error(embed_header + 'EXEC SQL DECLARE c CURSOR FOR VALUES 1;') == 'syntax error: an embedded SQL program must have an SQL statement'
}

// 21.2 <embedded exception declaration>: SQLSTATE and CONSTRAINT (Feature B041),
// and which declarations apply (SR 2).
fn test_embed_exceptions() ! {
	p := precompile_c(embed_header + 'EXEC SQL WHENEVER SQLSTATE (22) GOTO data;
EXEC SQL WHENEVER SQLSTATE (22, 012) GOTO zero;
EXEC SQL WHENEVER SQLSTATE(2B) GOTO dependent;
EXEC SQL WHENEVER SQLSTATE (42, P01) GO TO missing;
EXEC SQL WHENEVER CONSTRAINT c1 GOTO c1;
EXEC SQL WHENEVER CONSTRAINT s."c2" GOTO c2;
EXEC SQL WHENEVER CONSTRAINT x.s.c3 GOTO c3;
EXEC SQL WHENEVER SQLSTATE (01, 004) GOTO truncated;
EXEC SQL WHENEVER SQLSTATE (02) GOTO none;
EXEC SQL COMMIT;
EXEC SQL WHENEVER SQLSTATE (22) CONTINUE;
EXEC SQL WHENEVER CONSTRAINT c1 CONTINUE;
EXEC SQL WHENEVER SQLWARNING CONTINUE;
EXEC SQL WHENEVER NOT FOUND CONTINUE;
EXEC SQL COMMIT;
EXEC SQL WHENEVER SQLSTATE (23) GOTO integrity;
EXEC SQL COMMIT;
EXEC SQL WHENEVER CONSTRAINT c1 GOTO c1;
EXEC SQL WHENEVER SQLEXCEPTION CONTINUE;
EXEC SQL COMMIT;
',
		'x.sqc')!
	assert p.source.contains('static int vsql_m_violated(')
	assert p.source.contains('{ vsql_e1(SQLSTATE); if (vsql_m_violated(NULL, "PUBLIC", "C1")) goto c1; if (vsql_m_violated(NULL, "S", "c2")) goto c2; if (vsql_m_violated("X", "S", "C3")) goto c3; if (memcmp(SQLSTATE, "01004", 5) == 0) goto truncated; if (memcmp(SQLSTATE, "22012", 5) == 0) goto zero; if (memcmp(SQLSTATE, "42P01", 5) == 0) goto missing; if (memcmp(SQLSTATE, "02", 2) == 0) goto none; if (memcmp(SQLSTATE, "22", 2) == 0) goto data; if (memcmp(SQLSTATE, "2B", 2) == 0) goto dependent; }')
	assert p.source.contains('{ vsql_e2(SQLSTATE); if (vsql_m_violated(NULL, "S", "c2")) goto c2; if (vsql_m_violated("X", "S", "C3")) goto c3; if (memcmp(SQLSTATE, "42P01", 5) == 0) goto missing; if (memcmp(SQLSTATE, "2B", 2) == 0) goto dependent; }')
	assert p.source.contains('{ vsql_e3(SQLSTATE); if (memcmp(SQLSTATE, "42P01", 5) == 0) goto missing; if (memcmp(SQLSTATE, "23", 2) == 0) goto integrity; if (memcmp(SQLSTATE, "2B", 2) == 0) goto dependent; }')
	assert p.source.contains('{ vsql_e4(SQLSTATE); }')
}

fn test_embed_errors() ! {
	// 21.1 <embedded SQL host program>
	assert embed_error('int x;') == 'syntax error: an embedded SQL program must have an SQL statement'
	assert embed_error(embed_header + 'EXEC SQL COMMIT') == 'syntax error: line 4: EXEC SQL must end with a semicolon'
	assert embed_error(embed_header + "EXEC SQL VALUES 'a;") == "syntax error: line 4: unterminated string: 'a;"
	assert embed_error(embed_header + 'EXEC SQL /* a;') == 'syntax error: line 4: unterminated comment: /* a;'
	assert embed_error(embed_header + 'EXEC SQL BEGIN DECLARE SECTION;') == 'syntax error: line 4: END DECLARE SECTION is missing'
	assert embed_error(embed_header + 'EXEC SQL BEGIN DECLARE SECTION; EXEC SQL BEGIN DECLARE SECTION;') == 'syntax error: line 4: unexpected BEGIN DECLARE SECTION'
	assert embed_error('EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: unexpected END DECLARE SECTION'
	assert embed_error('EXEC SQL BEGIN DECLARE SECTION; EXEC SQL COMMIT;') == 'syntax error: line 1: a declare section can only contain host variable definitions'
	assert embed_error('EXEC SQL COMMIT;') == 'syntax error: line 1: SQLSTATE must be defined in a declare section before the first EXEC SQL'
	assert embed_error(embed_header + 'EXEC SQL BEGIN ROW;') == 'syntax error: line 4: unexpected ROW'
	assert embed_error(embed_header + 'EXEC SQL DELETE FROM t WHERE x = :z;') == 'syntax error: line 4: host variable :z is not defined'
	assert embed_error(embed_header + 'EXEC SQL COMMIT;\nEXEC SQL VALUES :a;') == 'syntax error: line 5: a query is not an SQL procedure statement, use SELECT ... INTO'
	assert embed_error(embed_header + 'EXEC SQL DECLARE SCHEMA s;') == 'syntax error: line 4: DECLARE SCHEMA and DECLARE AUTHORIZATION are not supported'
	assert embed_error(embed_header + 'EXEC SQL DECLARE c CURSOR FOR SELECT :z FROM t;') == 'syntax error: line 4: host variable :z is not defined'
	assert embed_error(embed_header + 'EXEC SQL OPEN c;') == 'syntax error: line 4: cursor C must be declared before it is opened'
	assert embed_error(embed_header + 'EXEC SQL OPEN 1;') == 'syntax error: line 4: expected a cursor name near 1'
	assert embed_error(embed_header + 'EXEC SQL "a') == 'syntax error: line 4: EXEC SQL must end with a semicolon'

	// 21.2 <embedded exception declaration>
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLERROR CONTINUE;') == 'syntax error: line 4: expected SQLEXCEPTION, SQLWARNING, NOT FOUND, SQLSTATE or CONSTRAINT near SQLERROR'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT x CONTINUE;') == 'syntax error: line 4: expected SQLEXCEPTION, SQLWARNING, NOT FOUND, SQLSTATE or CONSTRAINT near NOT'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT FOUND STOP;') == 'syntax error: line 4: expected CONTINUE, GOTO or GO TO near STOP'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT FOUND GOTO 1;') == 'syntax error: line 4: expected a label near 1'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER NOT FOUND CONTINUE x;') == 'syntax error: line 4: unexpected near x'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE 22 CONTINUE;') == 'syntax error: line 4: expected ( near 22'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE () CONTINUE;') == 'syntax error: line 4: expected SQLSTATE class code near )'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (2 2) CONTINUE;') == 'syntax error: line 4: SQLSTATE class code must be 2 digits or upper case letters: 2'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (hy) CONTINUE;') == 'syntax error: line 4: SQLSTATE class code must be 2 digits or upper case letters: hy'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (00) CONTINUE;') == 'syntax error: line 4: SQLSTATE class 00 is successful completion, which is not a condition'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (22, 01) CONTINUE;') == 'syntax error: line 4: SQLSTATE subclass code must be 3 digits or upper case letters: 01'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER SQLSTATE (22 CONTINUE;') == 'syntax error: line 4: expected ) near CONTINUE'
	assert embed_error(embed_header + 'EXEC SQL WHENEVER CONSTRAINT 1 CONTINUE;') == 'syntax error: line 4: expected a constraint name near 1'

	// 21.4 <embedded SQL C program>
	h := 'EXEC SQL BEGIN DECLARE SECTION; char SQLSTATE[6]; '
	for definition, expected in {
		'int x;':            'unsupported host variable definition: int x'
		'const;':            'unsupported host variable definition: const'
		'long 1x;':          'unsupported host variable definition: long 1x'
		'long [2];':         'unsupported host variable definition: long [2]'
		'long a, a;':        'host variable a is defined more than once'
		'long x[3];':        'host variable x must be a number, not an array'
		'char x;':           'host variable x must be an array of at least 2 characters'
		'VARCHAR x[1];':     'host variable x must be an array of at least 2 characters'
		'char SQLSTATE[5];': 'host variable SQLSTATE is defined more than once'
	} {
		assert embed_error(h + definition + ' EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: ${expected}', definition
	}
	assert embed_error('EXEC SQL BEGIN DECLARE SECTION; char SQLSTATE[5]; EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: SQLSTATE must be char SQLSTATE[6]'
	assert embed_error('EXEC SQL BEGIN DECLARE SECTION; long SQLSTATE; EXEC SQL END DECLARE SECTION;') == 'syntax error: line 1: SQLSTATE must be char SQLSTATE[6]'
}
