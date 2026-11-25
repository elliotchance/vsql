-- test_interval.mod is compiled and called by test_interval_main.c ("make
-- module-test"). It tests intervals in SQL descriptor areas.
MODULE interval LANGUAGE C AUTHORIZATION "PUBLIC"

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

PROCEDURE get_out (SQLSTATE, :n INTEGER, :type INTEGER, :code INTEGER,
    :leading INTEGER, :precision INTEGER, :length INTEGER);
  GET DESCRIPTOR out_d VALUE :n :type = TYPE, :code = DATETIME_INTERVAL_CODE,
    :leading = DATETIME_INTERVAL_PRECISION, :precision = PRECISION,
    :length = LENGTH;

PROCEDURE get_in (SQLSTATE, :type INTEGER, :code INTEGER, :leading INTEGER,
    :precision INTEGER);
  GET DESCRIPTOR in_d VALUE 1 :type = TYPE, :code = DATETIME_INTERVAL_CODE,
    :leading = DATETIME_INTERVAL_PRECISION, :precision = PRECISION;

PROCEDURE get_out_data (SQLSTATE, :n INTEGER, :data VARCHAR(60));
  GET DESCRIPTOR out_d VALUE :n :data = DATA;

PROCEDURE set_in_type (SQLSTATE, :type INTEGER);
  SET DESCRIPTOR in_d VALUE 1 TYPE = :type;

PROCEDURE set_in_code (SQLSTATE, :code INTEGER);
  SET DESCRIPTOR in_d VALUE 1 DATETIME_INTERVAL_CODE = :code;

PROCEDURE set_in_leading (SQLSTATE, :leading INTEGER);
  SET DESCRIPTOR in_d VALUE 1 DATETIME_INTERVAL_PRECISION = :leading;

PROCEDURE set_in_precision (SQLSTATE, :precision INTEGER);
  SET DESCRIPTOR in_d VALUE 1 PRECISION = :precision;

PROCEDURE set_in_data (SQLSTATE, :data VARCHAR(60));
  SET DESCRIPTOR in_d VALUE 1 DATA = :data;

PROCEDURE set_in_count (SQLSTATE);
  SET DESCRIPTOR in_d COUNT = 1;

PROCEDURE execute_s (SQLSTATE);
  EXECUTE s INTO SQL DESCRIPTOR out_d USING SQL DESCRIPTOR in_d;
