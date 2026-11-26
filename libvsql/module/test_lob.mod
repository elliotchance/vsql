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

-- SQL descriptor areas.

PROCEDURE allocate_out (SQLSTATE);
  ALLOCATE DESCRIPTOR out_d;

PROCEDURE allocate_in (SQLSTATE);
  ALLOCATE DESCRIPTOR in_d;

PROCEDURE prepare_s (SQLSTATE, :sql VARCHAR(200));
  PREPARE s FROM :sql;

PROCEDURE describe_output (SQLSTATE);
  DESCRIBE OUTPUT s USING SQL DESCRIPTOR out_d;

PROCEDURE describe_input (SQLSTATE);
  DESCRIBE INPUT s USING SQL DESCRIPTOR in_d;

PROCEDURE get_out (SQLSTATE, :n INTEGER, :type INTEGER, :length INTEGER,
    :octet_length INTEGER);
  GET DESCRIPTOR out_d VALUE :n :type = TYPE, :length = LENGTH,
    :octet_length = OCTET_LENGTH;

PROCEDURE get_in (SQLSTATE, :n INTEGER, :type INTEGER, :length INTEGER);
  GET DESCRIPTOR in_d VALUE :n :type = TYPE, :length = LENGTH;

PROCEDURE get_out_clob (SQLSTATE, :data CLOB(5), :returned INTEGER);
  GET DESCRIPTOR out_d VALUE 1 :data = DATA, :returned = RETURNED_LENGTH;

PROCEDURE get_out_blob (SQLSTATE, :data BLOB(6), :returned INTEGER);
  GET DESCRIPTOR out_d VALUE 2 :data = DATA, :returned = RETURNED_LENGTH;

PROCEDURE get_out_short_clob (SQLSTATE, :data CLOB(1));
  GET DESCRIPTOR out_d VALUE 1 :data = DATA;

PROCEDURE set_in_type (SQLSTATE, :n INTEGER, :type INTEGER);
  SET DESCRIPTOR in_d VALUE :n TYPE = :type;

PROCEDURE set_in_length (SQLSTATE, :n INTEGER, :length INTEGER);
  SET DESCRIPTOR in_d VALUE :n LENGTH = :length;

PROCEDURE set_in_clob (SQLSTATE, :data CLOB(4));
  SET DESCRIPTOR in_d VALUE 1 DATA = :data;

PROCEDURE set_in_blob (SQLSTATE, :data BLOB(4));
  SET DESCRIPTOR in_d VALUE 2 DATA = :data;

PROCEDURE set_in_varbinary (SQLSTATE, :data VARBINARY(4));
  SET DESCRIPTOR in_d VALUE 2 DATA = :data;

PROCEDURE set_in_count (SQLSTATE);
  SET DESCRIPTOR in_d COUNT = 2;

PROCEDURE execute_s (SQLSTATE);
  EXECUTE s INTO SQL DESCRIPTOR out_d USING SQL DESCRIPTOR in_d;
