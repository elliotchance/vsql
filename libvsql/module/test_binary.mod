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

PROCEDURE get_in (SQLSTATE, :type INTEGER, :length INTEGER);
  GET DESCRIPTOR in_d VALUE 1 :type = TYPE, :length = LENGTH;

PROCEDURE get_out_binary (SQLSTATE, :data BINARY(3));
  GET DESCRIPTOR out_d VALUE 1 :data = DATA;

PROCEDURE get_out_varbinary (SQLSTATE, :data VARBINARY(6),
    :returned INTEGER);
  GET DESCRIPTOR out_d VALUE 2 :data = DATA, :returned = RETURNED_LENGTH;

PROCEDURE get_out_char (SQLSTATE, :data CHAR(3));
  GET DESCRIPTOR out_d VALUE 1 :data = DATA;

PROCEDURE set_out_varbinary (SQLSTATE, :length INTEGER);
  SET DESCRIPTOR out_d VALUE 2 TYPE = 61, LENGTH = :length;

PROCEDURE set_in_type (SQLSTATE, :type INTEGER);
  SET DESCRIPTOR in_d VALUE 1 TYPE = :type;

PROCEDURE set_in_length (SQLSTATE, :length INTEGER);
  SET DESCRIPTOR in_d VALUE 1 LENGTH = :length;

PROCEDURE set_in_varbinary (SQLSTATE, :data VARBINARY(4));
  SET DESCRIPTOR in_d VALUE 1 DATA = :data;

PROCEDURE set_in_binary (SQLSTATE, :data BINARY(4));
  SET DESCRIPTOR in_d VALUE 1 DATA = :data;

PROCEDURE set_in_count (SQLSTATE);
  SET DESCRIPTOR in_d COUNT = 1;

PROCEDURE execute_s (SQLSTATE);
  EXECUTE s INTO SQL DESCRIPTOR out_d USING SQL DESCRIPTOR in_d;
