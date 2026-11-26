/* setup */
CREATE TABLE t (id INT PRIMARY KEY, x INT);
CREATE TABLE n (x INT);
CREATE TABLE d (id INT PRIMARY KEY, ts TIMESTAMP, s VARCHAR(10), tz TIMESTAMP WITH TIME ZONE);
CREATE TABLE e (id INT, ts TIMESTAMP, s VARCHAR(10), tz TIMESTAMP WITH TIME ZONE);
INSERT INTO t (id, x) VALUES (1, 10), (2, 20), (3, 30);
INSERT INTO n (x) VALUES (10), (20), (30);

-- # A row inserted through a view WITH CHECK OPTION must be seen through the
-- # view (15.17). Otherwise it's a with check option violation, and nothing is
-- # inserted.
CREATE VIEW v AS SELECT * FROM t WHERE x > 15 WITH CHECK OPTION;
INSERT INTO v VALUES (4, 40);
INSERT INTO v VALUES (5, 5);
INSERT INTO v VALUES (6, 60), (7, 7);
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V
-- error 44000: with check option violation: ":memory:".PUBLIC.V
-- ID: 1 X: 10
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 4 X: 40

-- # A row changed through the view must still be seen through it, including
-- # when its PRIMARY KEY is changed.
CREATE VIEW v AS SELECT * FROM t WHERE x > 15 WITH CHECK OPTION;
UPDATE v SET x = x + 1;
UPDATE v SET x = 1 WHERE id = 2;
UPDATE v SET x = x - 10;
UPDATE v SET id = 9 WHERE id = 2;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: UPDATE 2
-- error 44000: with check option violation: ":memory:".PUBLIC.V
-- error 44000: with check option violation: ":memory:".PUBLIC.V
-- msg: UPDATE 1
-- ID: 1 X: 10
-- ID: 3 X: 31
-- ID: 9 X: 21

-- # A row that isn't seen through the view can still be changed in the table,
-- # and DELETE isn't checked.
CREATE VIEW v AS SELECT * FROM t WHERE x > 15 WITH CHECK OPTION;
UPDATE t SET x = 1 WHERE id = 2;
DELETE FROM v;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: UPDATE 1
-- msg: DELETE 1
-- ID: 1 X: 10
-- ID: 2 X: 1

-- # A table without a PRIMARY KEY, and a view that renames its columns.
CREATE VIEW v (y) AS SELECT x FROM n WHERE x > 15 WITH CHECK OPTION;
INSERT INTO v VALUES (16);
INSERT INTO v VALUES (1);
UPDATE v SET y = 2;
UPDATE v SET y = y * 2;
SELECT * FROM n;
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V
-- error 44000: with check option violation: ":memory:".PUBLIC.V
-- msg: UPDATE 3
-- X: 10
-- X: 40
-- X: 60
-- X: 32

-- # A CHECK OPTION is CASCADED unless it's LOCAL (Syntax Rules, 16), so the
-- # rows are also checked with the WHERE of every view that the view reads
-- # (15.17, General Rules, 4.b.iii.5).
CREATE VIEW v1 AS SELECT * FROM t WHERE x < 100;
CREATE VIEW v2 AS SELECT * FROM v1 WHERE x > 15 WITH CHECK OPTION;
INSERT INTO v2 VALUES (4, 40);
INSERT INTO v2 VALUES (5, 500);
INSERT INTO v2 VALUES (6, 6);
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V2
-- error 44000: with check option violation: ":memory:".PUBLIC.V2
-- ID: 1 X: 10
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 4 X: 40

CREATE VIEW v1 AS SELECT * FROM t WHERE x < 100;
CREATE VIEW v2 AS SELECT * FROM v1 WHERE x > 15 WITH CASCADED CHECK OPTION;
INSERT INTO v2 VALUES (4, 40);
INSERT INTO v2 VALUES (5, 500);
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V2
-- ID: 1 X: 10
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 4 X: 40

-- # A LOCAL CHECK OPTION only checks the WHERE of the view, without the WHERE
-- # of the views that it reads (15.17, General Rules, 4.b.iii.5).
CREATE VIEW v1 AS SELECT * FROM t WHERE x < 100;
CREATE VIEW v2 AS SELECT * FROM v1 WHERE x > 15 WITH LOCAL CHECK OPTION;
INSERT INTO v2 VALUES (4, 40);
INSERT INTO v2 VALUES (5, 500);
INSERT INTO v2 VALUES (6, 6);
UPDATE v2 SET x = x * 10 WHERE id = 4;
UPDATE v2 SET x = 1 WHERE id = 2;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V2
-- msg: UPDATE 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V2
-- ID: 1 X: 10
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 4 X: 400
-- ID: 5 X: 500

-- # A view with CHECK OPTION that a view with LOCAL CHECK OPTION reads is
-- # still checked in its own right, with its own CASCADED or LOCAL.
CREATE VIEW v0 AS SELECT * FROM t WHERE x <> 50;
CREATE VIEW v1 AS SELECT * FROM v0 WHERE x < 100 WITH LOCAL CHECK OPTION;
CREATE VIEW v2 AS SELECT * FROM v1 WHERE x > 15 WITH LOCAL CHECK OPTION;
CREATE VIEW v3 AS SELECT * FROM v1 WHERE x > 15 WITH CHECK OPTION;
INSERT INTO v2 VALUES (4, 40);
INSERT INTO v2 VALUES (5, 500);
INSERT INTO v2 VALUES (6, 6);
INSERT INTO v2 VALUES (7, 50);
INSERT INTO v3 VALUES (8, 50);
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V1
-- error 44000: with check option violation: ":memory:".PUBLIC.V2
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V3
-- ID: 1 X: 10
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 4 X: 40
-- ID: 7 X: 50

-- # A view without CHECK OPTION that reads a view with CHECK OPTION is checked
-- # with the view that it reads (15.13 and 15.16, General Rules, 3.b.i), but
-- # not with its own WHERE.
CREATE VIEW v1 AS SELECT * FROM t WHERE x > 15 WITH CHECK OPTION;
CREATE VIEW v2 AS SELECT * FROM v1 WHERE x < 100;
INSERT INTO v2 VALUES (4, 400);
INSERT INTO v2 VALUES (5, 5);
UPDATE v2 SET x = 1;
SELECT * FROM t;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".PUBLIC.V1
-- error 44000: with check option violation: ":memory:".PUBLIC.V1
-- ID: 1 X: 10
-- ID: 2 X: 20
-- ID: 3 X: 30
-- ID: 4 X: 400

-- # The WHERE can have a subquery (E153), and the names in it are resolved in
-- # the schema of the view.
CREATE SCHEMA s;
CREATE TABLE s.t (id INT PRIMARY KEY, x INT);
CREATE TABLE s.allowed (x INT);
INSERT INTO s.allowed VALUES (1), (2);
CREATE VIEW s.v AS SELECT * FROM t WHERE x IN (SELECT x FROM allowed) WITH CHECK OPTION;
CREATE VIEW s.c AS SELECT id, (SELECT COUNT(*) FROM allowed) AS c FROM t;
INSERT INTO s.v VALUES (1, 1);
INSERT INTO s.v VALUES (2, 3);
UPDATE s.v SET x = 2;
SELECT * FROM s.v;
SELECT * FROM s.c;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: INSERT 1
-- error 44000: with check option violation: ":memory:".S.V
-- msg: UPDATE 1
-- ID: 1 X: 2
-- ID: 1 C: 2

-- # A positioned UPDATE is checked too (15.7, General Rules, 17.b.ii).
/* extensions V108-01 V109-01 V110-01 V113-01 */
CREATE VIEW v AS SELECT * FROM t WHERE x > 15 WITH CHECK OPTION;
START TRANSACTION;
DECLARE c CURSOR FOR SELECT * FROM v;
OPEN c;
FETCH NEXT FROM c;
UPDATE v SET x = 5 WHERE CURRENT OF c;
UPDATE v SET x = 25 WHERE CURRENT OF c;
SELECT * FROM t WHERE id = 2;
-- msg: CREATE VIEW 1
-- msg: START TRANSACTION
-- msg: DECLARE CURSOR
-- msg: OPEN
-- ID: 2 X: 20
-- error 44000: with check option violation: ":memory:".PUBLIC.V
-- msg: UPDATE 1
-- ID: 2 X: 25

-- # A view with CHECK OPTION must be updatable (Syntax Rules, 17).
CREATE VIEW v AS SELECT DISTINCT x FROM t WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM t WHERE x > (SELECT MIN(x) FROM t) WITH CHECK OPTION;
-- error 42601: syntax error: view ":memory:".PUBLIC.V is not updatable
-- error 42601: syntax error: view ":memory:".PUBLIC.V is not updatable

-- # A RECURSIVE view can't have a CHECK OPTION (Syntax Rules, 9.c).
CREATE RECURSIVE VIEW v (x) AS VALUES 1 WITH CHECK OPTION;
-- error 42601: syntax error: unexpected WITH at line 1, column 41 near "AS VALUES 1 WITH CHECK"

-- # The CHECK OPTION is kept with the view, and the INFORMATION_SCHEMA shows it
-- # as CASCADED or LOCAL.
CREATE VIEW v1 AS SELECT * FROM t WHERE x > 15 WITH CHECK OPTION;
CREATE VIEW v2 (a, b) AS SELECT * FROM t WITH  CHECK  OPTION;
CREATE VIEW v3 AS SELECT * FROM t;
CREATE VIEW v4 AS SELECT * FROM t WITH CASCADED CHECK OPTION;
CREATE VIEW v5 (a, b) AS SELECT * FROM t WHERE x > 15 WITH LOCAL CHECK OPTION;
SELECT table_name, view_definition, check_option FROM information_schema.views WHERE table_schema = 'PUBLIC';
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- TABLE_NAME: V1 VIEW_DEFINITION: SELECT * FROM t WHERE x > 15 CHECK_OPTION: CASCADED
-- TABLE_NAME: V2 VIEW_DEFINITION: SELECT * FROM t CHECK_OPTION: CASCADED
-- TABLE_NAME: V3 VIEW_DEFINITION: SELECT * FROM t CHECK_OPTION: NONE
-- TABLE_NAME: V4 VIEW_DEFINITION: SELECT * FROM t CHECK_OPTION: CASCADED
-- TABLE_NAME: V5 VIEW_DEFINITION: SELECT * FROM t WHERE x > 15 CHECK_OPTION: LOCAL

-- # LOCAL and CASCADED need Feature F751 (Conformance Rules, 2), and so does a
-- # CHECK OPTION on a view whose query contains another query (Conformance
-- # Rules, 4).
/* flags */
CREATE VIEW v AS SELECT * FROM t WHERE x > 15 WITH CHECK OPTION;
-- flags:
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v AS SELECT * FROM t WITH LOCAL CHECK OPTION;
-- flags: F751
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v AS SELECT * FROM t WITH CASCADED CHECK OPTION;
-- flags: F751
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v AS SELECT * FROM t WHERE x IN (SELECT x FROM n) WITH CHECK OPTION;
-- flags: F751
-- msg: CREATE VIEW 1

/* flags */
CREATE VIEW v AS SELECT * FROM t WHERE x IN (SELECT x FROM n);
-- flags:
-- msg: CREATE VIEW 1

-- # The query of a view with CHECK OPTION can't contain a potential source of
-- # non-determinism (Syntax Rules, 20, and 9.16), including in a subquery or a
-- # view that it reads.
CREATE VIEW v AS SELECT * FROM d WHERE ts < CURRENT_TIMESTAMP WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE ts < LOCALTIMESTAMP WITH LOCAL CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE s = CURRENT_SCHEMA WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE ts = tz WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE id IN (SELECT id FROM t WHERE x < EXTRACT(YEAR FROM CURRENT_DATE)) WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE s IN (SELECT DISTINCT s FROM e) WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE s IN (SELECT s FROM e GROUP BY s) WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE id IN (SELECT MAX(id) FROM e GROUP BY s HAVING s > 'a') WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE id IN (SELECT MAX(id) FROM e GROUP BY tz, s HAVING MIN(tz) IS NOT NULL) WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE id IN (SELECT id FROM t FETCH FIRST 1 ROW ONLY) WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE id IN (SELECT id FROM t OFFSET 1 ROW) WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE s IN (SELECT s FROM e UNION SELECT s FROM e) WITH CHECK OPTION;
CREATE VIEW v AS SELECT * FROM d WHERE tz IN (SELECT ts FROM e UNION ALL SELECT tz FROM e) WITH CHECK OPTION;
-- error 42601: syntax error: CURRENT_TIMESTAMP(6) cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: LOCALTIMESTAMP(6) cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: CURRENT_SCHEMA cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: comparing TIMESTAMP(6) WITHOUT TIME ZONE with TIMESTAMP(6) WITH TIME ZONE cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: CURRENT_DATE cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: SELECT DISTINCT of CHARACTER VARYING(10) cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: GROUP BY of CHARACTER VARYING(10) cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: GROUP BY of CHARACTER VARYING(10) cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: GROUP BY of TIMESTAMP(6) WITH TIME ZONE cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: FETCH FIRST cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: OFFSET cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: UNION of CHARACTER VARYING(10) and CHARACTER VARYING(10) cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: UNION of TIMESTAMP(6) WITHOUT TIME ZONE and TIMESTAMP(6) WITH TIME ZONE cannot be used in a view with CHECK OPTION

-- # A deterministic query is fine, and so is UNION ALL of strings, DISTINCT of
-- # numbers and a comparison with a time zone on both sides.
CREATE VIEW v AS SELECT * FROM d WHERE s IN (SELECT s FROM e UNION ALL SELECT s FROM e) AND id IN (SELECT DISTINCT x FROM t) AND tz < TIMESTAMP '2020-01-01 00:00:00+00:00' WITH CHECK OPTION;
-- msg: CREATE VIEW 1

-- # A grouping column that's a character string is fine when the select list
-- # and HAVING don't reference it, even in ORDER BY.
CREATE VIEW v AS SELECT * FROM d WHERE id IN (SELECT MAX(id) FROM e GROUP BY s HAVING COUNT(*) > 1) WITH CHECK OPTION;
CREATE VIEW w AS SELECT * FROM d WHERE id IN (SELECT MAX(id) FROM e GROUP BY s ORDER BY s) WITH CHECK OPTION;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1

-- # A view that it reads can't be non-deterministic either, except for the view
-- # in the FROM of a view with LOCAL CHECK OPTION (its leaf underlying table).
CREATE VIEW n1 AS SELECT * FROM d WHERE ts < CURRENT_TIMESTAMP;
CREATE VIEW n2 AS SELECT id FROM t WHERE x < EXTRACT(YEAR FROM CURRENT_DATE);
CREATE VIEW v1 AS SELECT * FROM n1 WITH CHECK OPTION;
CREATE VIEW v2 AS SELECT * FROM n1 WHERE id > 0 WITH LOCAL CHECK OPTION;
CREATE VIEW v3 AS SELECT * FROM d WHERE id IN (SELECT id FROM n2) WITH LOCAL CHECK OPTION;
CREATE VIEW v4 AS SELECT * FROM n1 WHERE id IN (SELECT id FROM n2) WITH CASCADED CHECK OPTION;
CREATE VIEW v5 AS SELECT * FROM n1;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- error 42601: syntax error: CURRENT_TIMESTAMP(6) cannot be used in a view with CHECK OPTION
-- msg: CREATE VIEW 1
-- error 42601: syntax error: CURRENT_DATE cannot be used in a view with CHECK OPTION
-- error 42601: syntax error: CURRENT_TIMESTAMP(6) cannot be used in a view with CHECK OPTION
-- msg: CREATE VIEW 1
