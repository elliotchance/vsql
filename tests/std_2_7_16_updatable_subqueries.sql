/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x INT);
CREATE TABLE u (id INT);
INSERT INTO t (id, x) VALUES (1, 10), (2, 20), (3, 30);
INSERT INTO u (id) VALUES (1), (3);
CREATE VIEW vt AS SELECT * FROM t;
CREATE VIEW vu AS SELECT * FROM u;

-- # A view is updatable even though its WHERE contains a subquery (Feature
-- # E153), as long as the subquery doesn't read the same table (7.16, Syntax
-- # Rules, 25.d).
CREATE VIEW v AS SELECT * FROM t WHERE id IN (SELECT id FROM u);
UPDATE v SET x = x + 1;
DELETE FROM v WHERE id = 3;
INSERT INTO v VALUES (4, 40);
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: UPDATE 2
-- msg: DELETE 1
-- msg: INSERT 1
-- ID: 1 X: 11
-- ID: 2 X: 20
-- ID: 4 X: 40

-- # A correlated subquery, EXISTS and NOT IN.
CREATE VIEW v1 AS SELECT * FROM t WHERE EXISTS (SELECT * FROM u WHERE u.id = t.id);
CREATE VIEW v2 AS SELECT * FROM t WHERE id NOT IN (SELECT id FROM u);
UPDATE v1 SET x = 0;
DELETE FROM v2;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: UPDATE 2
-- msg: DELETE 1
-- ID: 1 X: 0
-- ID: 3 X: 0

-- # The subquery can read another view, or a view can read another view, as
-- # long as they don't read the same table in the end.
CREATE VIEW v1 AS SELECT * FROM t WHERE id IN (SELECT id FROM vu);
CREATE VIEW v2 AS SELECT * FROM vt WHERE id IN (SELECT id FROM u);
UPDATE v1 SET x = 1;
UPDATE v2 SET x = x + 1;
SELECT * FROM t;
SELECT table_name, is_updatable FROM information_schema.views WHERE table_name IN ('V1', 'V2');
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: UPDATE 2
-- msg: UPDATE 2
-- ID: 1 X: 2
-- ID: 2 X: 20
-- ID: 3 X: 2
-- TABLE_NAME: V1 IS_UPDATABLE: YES
-- TABLE_NAME: V2 IS_UPDATABLE: YES

-- # The view isn't updatable if the subquery reads the same table in the end,
-- # through a view, or a subquery of the subquery.
CREATE VIEW v1 AS SELECT * FROM t WHERE x > (SELECT MIN(x) FROM vt);
CREATE VIEW v2 AS SELECT * FROM vt WHERE x > (SELECT MIN(x) FROM t);
CREATE VIEW v3 AS SELECT * FROM t WHERE id IN (SELECT id FROM u WHERE id IN (SELECT id FROM vt));
UPDATE v1 SET x = 1;
DELETE FROM v2;
DELETE FROM v3;
SELECT table_name, is_updatable FROM information_schema.views WHERE table_name IN ('V1', 'V2', 'V3');
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- error 42601: syntax error: view ":memory:".PUBLIC.V1 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V2 is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V3 is not updatable
-- TABLE_NAME: V1 IS_UPDATABLE: NO
-- TABLE_NAME: V2 IS_UPDATABLE: NO
-- TABLE_NAME: V3 IS_UPDATABLE: NO

-- # A cursor is updatable even though its WHERE contains a subquery, but not
-- # when the subquery reads the same table in the end.
/* extensions V108-01 V109-01 V110-01 V113-01 */
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM vt WHERE id NOT IN (SELECT id FROM u) FOR UPDATE;
DECLARE d CURSOR FOR SELECT * FROM vt WHERE x > (SELECT MIN(x) FROM t) FOR UPDATE;
OPEN c;
FETCH NEXT FROM c;
UPDATE vt SET x = 99 WHERE CURRENT OF c;
SELECT * FROM t WHERE id = 2;
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- error 42601: syntax error: cursor D is not updatable
-- msg: OPEN
-- ID: 2 X: 20
-- msg: UPDATE 1
-- ID: 2 X: 99

-- # A subquery can also give the new value of a column.
UPDATE vt SET x = (SELECT COUNT(*) FROM u) WHERE id = 2;
UPDATE t SET x = (SELECT MAX(id) FROM vu) WHERE id IN (SELECT id FROM u);
SELECT * FROM t;
-- msg: UPDATE 1
-- msg: UPDATE 2
-- ID: 1 X: 3
-- ID: 2 X: 2
-- ID: 3 X: 3
