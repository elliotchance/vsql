-- test.mod is compiled and called by test_main.c ("make module-test").
MODULE "Test Module" LANGUAGE C AUTHORIZATION "PUBLIC"

PROCEDURE connect_default (SQLSTATE);
  CONNECT TO DEFAULT;

PROCEDURE connect_to (:server CHAR(50), :name VARCHAR(50), SQLSTATE);
  CONNECT TO :server AS :name;

PROCEDURE connect_user (SQLSTATE, :name VARCHAR(50), :user VARCHAR(50));
  CONNECT TO ':memory:' AS :name USER :user;

PROCEDURE connect_literal (SQLSTATE);
  CONNECT TO ':memory:' AS 'literal';

PROCEDURE set_connection (SQLSTATE, :name VARCHAR(50));
  SET CONNECTION :name;

PROCEDURE set_connection_default (SQLSTATE);
  SET CONNECTION DEFAULT;

PROCEDURE disconnect (SQLSTATE, :name VARCHAR(50));
  DISCONNECT :name;

PROCEDURE disconnect_default (SQLSTATE);
  DISCONNECT DEFAULT;

PROCEDURE disconnect_current (SQLSTATE);
  DISCONNECT CURRENT;

PROCEDURE disconnect_all (SQLSTATE);
  DISCONNECT ALL;

PROCEDURE create_table (SQLSTATE);
  CREATE TABLE t (
    s SMALLINT, i INTEGER, b BIGINT, r REAL, d DOUBLE PRECISION,
    c CHARACTER(5), v CHARACTER VARYING(10), f BOOLEAN
  );

PROCEDURE insert_row (SQLSTATE, :s SMALLINT, :i INT, :b BIGINT, :r REAL,
    :d DOUBLE PRECISION, :c CHAR(5), :v VARCHAR(10), :f BOOLEAN,
    :v_null INTEGER, :unused BIGINT);
  /* Every type, and :v can be NULL. */
  INSERT INTO t (s, i, b, r, d, c, v, f)
  VALUES (:s, :i, :b, :r, :d, :c, :v :v_null, :f);

PROCEDURE check_row (SQLSTATE, :c CHARACTER(5), :f BOOLEAN);
  -- 22012 (division by zero) unless a row matches.
  INSERT INTO t (s) VALUES (1 / (SELECT COUNT(*) FROM t
    WHERE s = 1 AND i = 2 AND b = 3 AND r = 4.5 AND d = 5.5 AND c = :c
    AND v IS NULL AND f = :f));

PROCEDURE count_rows (SQLSTATE, :n BIGINT);
  -- 22012 if there are :n rows.
  INSERT INTO t (s) VALUES (1 / ((SELECT COUNT(*) FROM t) - :n));

PROCEDURE start_transaction (SQLSTATE);
  START TRANSACTION;

PROCEDURE commit_work (SQLSTATE);
  COMMIT WORK;

PROCEDURE rollback_work (SQLSTATE);
  ROLLBACK;

PROCEDURE missing_table (SQLSTATE);
  DELETE FROM missing;
