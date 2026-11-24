-- test_binary.mod is compiled and called by test_binary_main.c ("make
-- module-test"). It tests BINARY and BINARY VARYING host parameters.
MODULE bin LANGUAGE C AUTHORIZATION "PUBLIC"

PROCEDURE create_t (SQLSTATE);
  CREATE TABLE t (id INTEGER, b BINARY(4), v VARBINARY(6));

PROCEDURE insert_t (SQLSTATE, :id INTEGER, :b BINARY(4), :v VARBINARY(6),
    :vi SMALLINT);
  INSERT INTO t (id, b, v) VALUES (:id, :b, :v :vi);

PROCEDURE select_t (SQLSTATE, :id INTEGER, :b BINARY(4), :bi INTEGER,
    :v VARBINARY(6), :vi INTEGER);
  SELECT b, v INTO :b :bi, :v :vi FROM t WHERE id = :id;

PROCEDURE select_short (SQLSTATE, :id INTEGER, :b BINARY(2), :bi INTEGER,
    :v BINARY VARYING(3), :vi INTEGER);
  SELECT b, v INTO :b :bi, :v :vi FROM t WHERE id = :id;

PROCEDURE select_no_indicator (SQLSTATE, :id INTEGER, :v VARBINARY(6));
  SELECT v INTO :v FROM t WHERE id = :id;

PROCEDURE select_char (SQLSTATE, :b BINARY(4));
  SELECT 'a' INTO :b FROM t WHERE id = 1;

PROCEDURE rollback_t (SQLSTATE);
  ROLLBACK;
