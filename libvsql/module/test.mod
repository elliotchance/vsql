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

PROCEDURE create_schema (SQLSTATE);
  CREATE SCHEMA other;

PROCEDURE start_transaction (SQLSTATE);
  START TRANSACTION;

PROCEDURE commit_work (SQLSTATE);
  COMMIT WORK;

PROCEDURE rollback_work (SQLSTATE);
  ROLLBACK;

PROCEDURE missing_table (SQLSTATE);
  DELETE FROM missing;

PROCEDURE select_row (SQLSTATE, :s SMALLINT, :i INTEGER, :b BIGINT, :r REAL,
    :d DOUBLE PRECISION, :c CHARACTER(5), :v VARCHAR(10), :v_ind SMALLINT,
    :f BOOLEAN);
  SELECT s, i, b, r, d, c, v, f
  INTO :s, :i, :b, :r, :d, :c, :v INDICATOR :v_ind, :f
  FROM t WHERE i = :i;

PROCEDURE select_s (SQLSTATE, :s SMALLINT, :i INTEGER);
  -- More than one row, unless :i is 2.
  SELECT s INTO :s FROM t WHERE i = :i OR i IS NULL;

PROCEDURE select_strings (SQLSTATE, :c CHAR(3), :c_ind BIGINT, :v VARCHAR(3),
    :v_ind INTEGER, :n BIGINT);
  SELECT /* INTO */ 'into', "V", (SELECT COUNT(*) FROM t WHERE 'INTO' <> '')
  INTO :c :c_ind, :v :v_ind, :n FROM t WHERE i = 2;

-- A string has a length in characters, not octets.
PROCEDURE select_utf8 (SQLSTATE, :c CHAR(3), :v VARCHAR(3), :p CHAR(5));
  SELECT 'ééé', 'é€😀', 'é' INTO :c, :v, :p FROM t WHERE i = 2;

PROCEDURE select_utf8_long (SQLSTATE, :c CHAR(1), :v VARCHAR(3));
  SELECT 'é€', '😀😀😀😀' INTO :c, :v FROM t WHERE i = 2;

PROCEDURE select_null (SQLSTATE, :i BIGINT);
  SELECT i INTO :i FROM t WHERE i IS NULL;

PROCEDURE select_all (SQLSTATE, :s SMALLINT);
  SELECT * INTO :s FROM t WHERE i = 2;

PROCEDURE get_statement (SQLSTATE, :number INTEGER, :more CHARACTER(1),
    :function VARCHAR(30), :code SMALLINT, :dynamic CHAR(2),
    :dynamic_code BIGINT, :rows BIGINT, :committed INTEGER,
    :rolled_back INTEGER, :active INTEGER);
  GET DIAGNOSTICS :number = NUMBER, :more = MORE,
    :function = COMMAND_FUNCTION, :code = COMMAND_FUNCTION_CODE,
    :dynamic = DYNAMIC_FUNCTION, :dynamic_code = DYNAMIC_FUNCTION_CODE,
    :rows = ROW_COUNT, :committed = TRANSACTIONS_COMMITTED,
    :rolled_back = TRANSACTIONS_ROLLED_BACK, :active = TRANSACTION_ACTIVE;

PROCEDURE get_condition (SQLSTATE, :n INTEGER, :number BIGINT,
    :state CHAR(5), :message VARCHAR(100), :length INTEGER,
    :octet_length INTEGER, :class_origin VARCHAR(10),
    :subclass_origin VARCHAR(10), :connection VARCHAR(50),
    :server VARCHAR(50), :table VARCHAR(10));
  GET DIAGNOSTICS CONDITION :n :number = CONDITION_NUMBER,
    :state = RETURNED_SQLSTATE, :message = MESSAGE_TEXT,
    :length = MESSAGE_LENGTH, :octet_length = MESSAGE_OCTET_LENGTH,
    :class_origin = CLASS_ORIGIN, :subclass_origin = SUBCLASS_ORIGIN,
    :connection = CONNECTION_NAME, :server = SERVER_NAME,
    :table = TABLE_NAME;

PROCEDURE get_short_message (SQLSTATE, :message CHAR(3));
  GET DIAGNOSTICS CONDITION 1 :message = MESSAGE_TEXT;

DECLARE c1 CURSOR FOR SELECT x, y FROM cur WHERE x >= :min;

DECLARE "held" CURSOR WITH HOLD FOR SELECT x FROM cur;

PROCEDURE create_cur (SQLSTATE);
  CREATE TABLE cur (x INTEGER, y VARCHAR(10));

PROCEDURE insert_cur (SQLSTATE, :x INTEGER, :y VARCHAR(10));
  INSERT INTO cur (x, y) VALUES (:x, :y);

PROCEDURE open_c1 (SQLSTATE, :min INTEGER);
  OPEN c1;

PROCEDURE fetch_c1 (SQLSTATE, :x INTEGER, :y VARCHAR(3), :y_ind INTEGER);
  FETCH NEXT FROM c1 INTO :x, :y INDICATOR :y_ind;

PROCEDURE close_c1 (SQLSTATE);
  CLOSE c1;

PROCEDURE update_c1 (SQLSTATE, :y VARCHAR(10));
  UPDATE cur SET y = :y WHERE CURRENT OF c1;

PROCEDURE delete_c1 (SQLSTATE);
  DELETE FROM cur WHERE CURRENT OF c1;

PROCEDURE open_held (SQLSTATE);
  OPEN "held";

PROCEDURE fetch_held (SQLSTATE, :x INTEGER);
  FETCH "held" INTO :x;

PROCEDURE delete_held (SQLSTATE);
  DELETE FROM cur WHERE CURRENT OF "held";

-- A procedure can use a cursor that's declared after it.
PROCEDURE open_all (SQLSTATE);
  OPEN c_all;

PROCEDURE fetch_all (SQLSTATE, :x INTEGER);
  FETCH FROM c_all INTO :x;

DECLARE c_all CURSOR FOR SELECT * FROM cur;

-- Feature B031, "Basic dynamic SQL".
PROCEDURE execute_immediate (SQLSTATE, :sql VARCHAR(100));
  EXECUTE IMMEDIATE :sql;

PROCEDURE prepare_s1 (SQLSTATE, :sql VARCHAR(100));
  PREPARE s1 FROM :sql;

PROCEDURE execute_s1 (SQLSTATE);
  EXECUTE s1;

PROCEDURE execute_s1_using (SQLSTATE, :x INTEGER, :y VARCHAR(10),
    :y_ind INTEGER);
  EXECUTE s1 USING :x, :y INDICATOR :y_ind;

PROCEDURE execute_s1_into (SQLSTATE, :x INTEGER, :y VARCHAR(10),
    :y_ind INTEGER, :min INTEGER);
  EXECUTE s1 INTO :x, :y :y_ind USING :min;

PROCEDURE execute_s1_descriptor (SQLSTATE);
  EXECUTE s1 INTO SQL DESCRIPTOR d USING SQL DESCRIPTOR 'in';

PROCEDURE deallocate_s1 (SQLSTATE);
  DEALLOCATE PREPARE s1;

PROCEDURE describe_s1 (SQLSTATE);
  DESCRIBE OUTPUT s1 USING SQL DESCRIPTOR d;

PROCEDURE prepare_s2 (SQLSTATE);
  PREPARE s2 FROM 'SELECT x, y FROM dyn WHERE x > ?';

PROCEDURE deallocate_s2 (SQLSTATE);
  DEALLOCATE PREPARE s2;

PROCEDURE allocate_d (SQLSTATE, :max INTEGER);
  ALLOCATE DESCRIPTOR d WITH MAX :max;

PROCEDURE allocate_in (SQLSTATE);
  ALLOCATE SQL DESCRIPTOR LOCAL ' in ';

PROCEDURE allocate_global (SQLSTATE);
  ALLOCATE DESCRIPTOR GLOBAL 'g' WITH MAX 3;

PROCEDURE deallocate_d (SQLSTATE);
  DEALLOCATE DESCRIPTOR d;

PROCEDURE get_header (SQLSTATE, :count INTEGER, :top SMALLINT, :key BIGINT,
    :function VARCHAR(30), :code INTEGER);
  GET DESCRIPTOR d :count = COUNT, :top = TOP_LEVEL_COUNT, :key = KEY_TYPE,
    :function = DYNAMIC_FUNCTION, :code = DYNAMIC_FUNCTION_CODE;

PROCEDURE get_item (SQLSTATE, :n INTEGER, :type INTEGER, :length INTEGER,
    :name VARCHAR(20), :nullable INTEGER, :indicator INTEGER,
    :returned INTEGER);
  GET DESCRIPTOR d VALUE :n :type = TYPE, :length = LENGTH, :name = NAME,
    :nullable = NULLABLE, :indicator = INDICATOR,
    :returned = RETURNED_LENGTH;

PROCEDURE get_int (SQLSTATE, :n INTEGER, :x INTEGER, :ind INTEGER);
  GET DESCRIPTOR d VALUE :n :x = DATA, :ind = INDICATOR;

PROCEDURE get_varchar (SQLSTATE, :n INTEGER, :y VARCHAR(10));
  GET DESCRIPTOR d VALUE :n :y = DATA;

PROCEDURE set_count (SQLSTATE, :count INTEGER);
  SET DESCRIPTOR d COUNT = :count;

PROCEDURE set_int (SQLSTATE, :n INTEGER, :x INTEGER);
  -- TYPE is set before DATA (20.5 GR 4).
  SET DESCRIPTOR d VALUE :n DATA = :x, TYPE = 4, INDICATOR = 0;

PROCEDURE set_varchar (SQLSTATE, :n INTEGER, :y VARCHAR(10));
  SET SQL DESCRIPTOR d VALUE :n TYPE = 12, LENGTH = 10, DATA = :y;

PROCEDURE set_in (SQLSTATE, :x INTEGER);
  SET DESCRIPTOR 'in' VALUE 1 TYPE = 4, DATA = :x;

PROCEDURE set_in_count (SQLSTATE);
  SET DESCRIPTOR 'in' COUNT = 1;

PROCEDURE set_null (SQLSTATE, :n INTEGER);
  SET DESCRIPTOR d VALUE :n INDICATOR = -1;

PROCEDURE set_level (SQLSTATE, :level INTEGER);
  SET DESCRIPTOR d VALUE 1 LEVEL = :level;

PROCEDURE set_code (SQLSTATE, :code INTEGER);
  SET DESCRIPTOR d VALUE 1 TYPE = 9, DATETIME_INTERVAL_CODE = :code;

DECLARE dc CURSOR WITH HOLD FOR s2;

PROCEDURE open_dc (SQLSTATE, :min INTEGER);
  OPEN dc USING :min;

PROCEDURE open_dc_descriptor (SQLSTATE);
  OPEN dc USING DESCRIPTOR d;

PROCEDURE fetch_dc (SQLSTATE, :x INTEGER, :y VARCHAR(10));
  FETCH NEXT FROM dc INTO :x, :y;

PROCEDURE fetch_dc_descriptor (SQLSTATE);
  FETCH dc INTO SQL DESCRIPTOR d;

PROCEDURE update_dc (SQLSTATE, :y VARCHAR(10));
  UPDATE dyn SET y = :y WHERE CURRENT OF dc;

PROCEDURE delete_dc (SQLSTATE);
  DELETE FROM dyn WHERE CURRENT OF dc;

PROCEDURE close_dc (SQLSTATE);
  CLOSE dc;
