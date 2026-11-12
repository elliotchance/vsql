-- test_updatability.mod is compiled and called by test_updatability_main.c
-- ("make module-test"), for the <updatability clause> of a cursor.
MODULE updatability LANGUAGE C AUTHORIZATION "PUBLIC"

DECLARE read_only CURSOR FOR SELECT x, y FROM upd FOR READ ONLY;

DECLARE update_y CURSOR FOR SELECT x, y FROM upd ORDER BY x FOR UPDATE OF y;

PROCEDURE create_upd (SQLSTATE);
  CREATE TABLE upd (x INTEGER, y INTEGER);

PROCEDURE insert_upd (SQLSTATE);
  INSERT INTO upd (x, y) VALUES (1, 10), (2, 20);

PROCEDURE open_read_only (SQLSTATE);
  OPEN read_only;

PROCEDURE fetch_read_only (SQLSTATE, :x INTEGER, :y INTEGER);
  FETCH read_only INTO :x, :y;

PROCEDURE delete_read_only (SQLSTATE);
  DELETE FROM upd WHERE CURRENT OF read_only;

PROCEDURE update_read_only (SQLSTATE);
  UPDATE upd SET y = 0 WHERE CURRENT OF read_only;

PROCEDURE open_update_y (SQLSTATE);
  OPEN update_y;

PROCEDURE fetch_update_y (SQLSTATE, :x INTEGER, :y INTEGER);
  FETCH update_y INTO :x, :y;

PROCEDURE set_x (SQLSTATE);
  UPDATE upd SET x = 5 WHERE CURRENT OF update_y;

PROCEDURE set_y (SQLSTATE, :y INTEGER);
  UPDATE upd SET y = :y WHERE CURRENT OF update_y;

PROCEDURE close_update_y (SQLSTATE);
  CLOSE update_y;

PROCEDURE sum_y (SQLSTATE, :y INTEGER);
  SELECT SUM(y) INTO :y FROM upd;

PROCEDURE commit_work (SQLSTATE);
  COMMIT WORK;
