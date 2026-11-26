-- test_decfloat.mod is compiled and called by test_decfloat_main.c ("make
-- module-test"). It tests DECFLOAT in SQL descriptor areas.
MODULE decfloat LANGUAGE C AUTHORIZATION "PUBLIC"

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

PROCEDURE get_out (SQLSTATE, :n INTEGER, :type INTEGER, :precision INTEGER,
    :scale INTEGER);
  GET DESCRIPTOR out_d VALUE :n :type = TYPE, :precision = PRECISION,
    :scale = SCALE;

PROCEDURE get_in (SQLSTATE, :type INTEGER, :precision INTEGER);
  GET DESCRIPTOR in_d VALUE 1 :type = TYPE, :precision = PRECISION;

PROCEDURE get_out_data (SQLSTATE, :data VARCHAR(50));
  GET DESCRIPTOR out_d VALUE 1 :data = DATA;

PROCEDURE get_out_double (SQLSTATE, :data DOUBLE PRECISION);
  GET DESCRIPTOR out_d VALUE 1 :data = DATA;

PROCEDURE set_in_type (SQLSTATE, :type INTEGER);
  SET DESCRIPTOR in_d VALUE 1 TYPE = :type;

PROCEDURE set_in_precision (SQLSTATE, :precision INTEGER);
  SET DESCRIPTOR in_d VALUE 1 PRECISION = :precision;

PROCEDURE set_in_data (SQLSTATE, :data VARCHAR(50));
  SET DESCRIPTOR in_d VALUE 1 DATA = :data;

PROCEDURE set_in_count (SQLSTATE);
  SET DESCRIPTOR in_d COUNT = 1;

PROCEDURE execute_s (SQLSTATE);
  EXECUTE s INTO SQL DESCRIPTOR out_d USING SQL DESCRIPTOR in_d;
