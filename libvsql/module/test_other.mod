-- test_other.mod is a second module that's linked with test.mod by
-- "make module-test", for Feature F181 ("Multiple module support"). The
-- schema is created by test_main.c before this module is called.
MODULE other LANGUAGE C SCHEMA other

-- The cursor of test.mod with the same index (c1) is a different cursor.
DECLARE c2 CURSOR FOR SELECT x FROM "PUBLIC".cur;

PROCEDURE other_count (SQLSTATE, :n BIGINT);
  SELECT COUNT(*) INTO :n FROM "PUBLIC".cur;

-- OTHER.CUR isn't PUBLIC.CUR.
PROCEDURE other_create (SQLSTATE);
  CREATE TABLE cur (x INTEGER);

PROCEDURE other_count_own (SQLSTATE, :n BIGINT);
  SELECT COUNT(*) INTO :n FROM cur;

PROCEDURE other_missing (SQLSTATE);
  DELETE FROM missing;

PROCEDURE other_open (SQLSTATE);
  OPEN c2;

PROCEDURE other_fetch (SQLSTATE, :x INTEGER);
  FETCH c2 INTO :x;

PROCEDURE other_close (SQLSTATE);
  CLOSE c2;

PROCEDURE other_disconnect (SQLSTATE);
  DISCONNECT CURRENT;
