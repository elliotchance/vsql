-- test_more.mod is for the tests of GET DIAGNOSTICS MORE in test_more_main.c,
-- which needs a DIAGNOSTICS SIZE before the first SQL-transaction.
MODULE "More Module" LANGUAGE C AUTHORIZATION "PUBLIC"

PROCEDURE set_size_1 (SQLSTATE);
  SET TRANSACTION DIAGNOSTICS SIZE 1;

PROCEDURE select_two_warnings (SQLSTATE, :a CHARACTER(1), :b CHARACTER(1));
  SELECT CAST('abc' AS CHAR(1)), CAST('xyz' AS CHAR(1)) INTO :a, :b
    FROM (VALUES 1) AS t (x);

-- The CAST raises a warning, and the target truncates another value.
PROCEDURE select_truncated (SQLSTATE, :a CHARACTER(1), :b CHARACTER(1));
  SELECT CAST('abc' AS CHAR(1)), 'xyz' INTO :a, :b FROM (VALUES 1) AS t (x);

PROCEDURE select_ok (SQLSTATE, :a CHARACTER(1));
  SELECT 'a' INTO :a FROM (VALUES 1) AS t (x);

PROCEDURE prepare_two_warnings (SQLSTATE);
  PREPARE s1 FROM 'SELECT CAST(''abc'' AS CHAR(1)), CAST(''xyz'' AS CHAR(1)) FROM (VALUES 1) AS t (x)';

PROCEDURE execute_two_warnings (SQLSTATE, :a CHARACTER(1), :a_ind INTEGER,
    :b CHARACTER(1), :b_ind INTEGER);
  EXECUTE s1 INTO :a :a_ind, :b :b_ind;

PROCEDURE get_more (SQLSTATE, :number INTEGER, :more CHARACTER(1),
    :active INTEGER);
  GET DIAGNOSTICS :number = NUMBER, :more = MORE, :active = TRANSACTION_ACTIVE;

PROCEDURE commit_work (SQLSTATE);
  COMMIT WORK;
