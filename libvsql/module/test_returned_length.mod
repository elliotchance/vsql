-- test_returned_length.mod is compiled and called by
-- test_returned_length_main.c ("make module-test").
MODULE returned_length LANGUAGE C AUTHORIZATION "PUBLIC"

PROCEDURE allocate_d (SQLSTATE);
  ALLOCATE DESCRIPTOR d;

PROCEDURE prepare_s (SQLSTATE, :sql VARCHAR(1000));
  PREPARE s FROM :sql;

PROCEDURE describe_s (SQLSTATE);
  DESCRIBE OUTPUT s USING SQL DESCRIPTOR d;

PROCEDURE set_type (SQLSTATE, :type INTEGER, :length INTEGER);
  SET DESCRIPTOR d VALUE 1 TYPE = :type, LENGTH = :length;

PROCEDURE execute_s (SQLSTATE);
  EXECUTE s INTO SQL DESCRIPTOR d;

PROCEDURE get_lengths (SQLSTATE, :n INTEGER, :o INTEGER, :indicator INTEGER);
  GET DESCRIPTOR d VALUE 1 :n = RETURNED_LENGTH, :o = RETURNED_OCTET_LENGTH,
    :indicator = INDICATOR;

PROCEDURE get_char (SQLSTATE, :data CHAR(1));
  GET DESCRIPTOR d VALUE 1 :data = DATA;

PROCEDURE get_integer (SQLSTATE, :data INTEGER);
  GET DESCRIPTOR d VALUE 1 :data = DATA;

PROCEDURE get_varchar (SQLSTATE, :data VARCHAR(20));
  GET DESCRIPTOR d VALUE 1 :data = DATA;
