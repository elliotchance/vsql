-- test_lob.mod is compiled and called by test_lob_main.c ("make
-- module-test"). It tests CHARACTER LARGE OBJECT and BINARY LARGE OBJECT host
-- parameters.
MODULE lob LANGUAGE C AUTHORIZATION "PUBLIC"

PROCEDURE create_t (SQLSTATE);
  CREATE TABLE t (id INTEGER, c CLOB(10), b BLOB(10));

PROCEDURE insert_t (SQLSTATE, :id INTEGER, :c CLOB(4), :b BLOB(6),
    :bi SMALLINT);
  INSERT INTO t (id, c, b) VALUES (:id, :c, :b :bi);

PROCEDURE select_t (SQLSTATE, :id INTEGER, :c CHARACTER LARGE OBJECT(4),
    :ci INTEGER, :b BINARY LARGE OBJECT(6), :bi INTEGER);
  SELECT c, b INTO :c :ci, :b :bi FROM t WHERE id = :id;

PROCEDURE select_short (SQLSTATE, :id INTEGER, :c CLOB(2), :ci INTEGER,
    :b BLOB(1), :bi INTEGER);
  SELECT c, b INTO :c :ci, :b :bi FROM t WHERE id = :id;

PROCEDURE select_no_indicator (SQLSTATE, :id INTEGER, :b BLOB(6));
  SELECT b INTO :b FROM t WHERE id = :id;

PROCEDURE rollback_t (SQLSTATE);
  ROLLBACK;
