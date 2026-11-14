-- # The Conformance Rules that depend on what a name refers to, which is found
-- # with the catalog.
/* setup */
CREATE TABLE t (x INT NOT NULL, y INT);
CREATE TABLE u (x INT NOT NULL, z INT);
CREATE SCHEMA s;
CREATE TABLE s.t (x INT NOT NULL);
CREATE TABLE p1 (id INT NOT NULL PRIMARY KEY, v VARCHAR(10) NOT NULL UNIQUE, n NUMERIC(10, 2) NOT NULL UNIQUE);
CREATE TABLE c1 (a INT REFERENCES p1, b BIGINT);
CREATE TABLE old_key (a BIGINT REFERENCES p1, b INT);
INSERT INTO t (x, y) VALUES (1, 2);
INSERT INTO u (x, z) VALUES (1, 3);

-- # ISO/IEC 9075-2:2023, 7.12, <where clause>, Conformance Rules, 1

/* flags */
SELECT * FROM (SELECT COUNT(*) AS c FROM t) AS d WHERE c > 0;
-- flags: F441, F591
-- C: 1

/* flags */
SELECT * FROM (SELECT COUNT(*) AS c FROM t) AS d WHERE d.c > 0;
-- flags: F441, F591
-- C: 1

/* flags */
SELECT * FROM (SELECT COUNT(*) + 1 FROM t) AS d (c) WHERE c > 0;
-- flags: F441, F591
-- C: 2

/* flags */
SELECT * FROM (SELECT x, COUNT(*) AS c FROM t GROUP BY x) AS d, u WHERE c > 0 AND z > 0;
-- flags: F441, F591
-- X: 1 C: 1 X: 1 Z: 3

/* flags */
SELECT * FROM (SELECT COUNT(*) AS c FROM t) AS d WHERE EXISTS (SELECT z FROM u WHERE d.c > 0);
-- flags: F441, F591
-- C: 1

-- # A column of the same derived table that isn't from an aggregate function,
-- # or a column of a table in a subquery that hides the derived column.

/* flags */
SELECT * FROM (SELECT x, COUNT(*) AS c FROM t GROUP BY x) AS d WHERE x > 0;
-- flags: F591
-- X: 1 C: 1

/* flags */
SELECT * FROM (SELECT COUNT(*) AS x FROM t) AS d WHERE EXISTS (SELECT z FROM u WHERE x > 0);
-- flags: F591
-- X: 1

/* flags */
SELECT * FROM (SELECT x AS c FROM t) AS d WHERE c > 0;
-- flags: F591
-- C: 1

/* flags */
SELECT COUNT(*) AS c FROM t HAVING COUNT(*) > 0;
-- flags:
-- C: 1

-- # ISO/IEC 9075-2:2023, 10.9, <aggregate function>, Conformance Rules, 6, 8 and 19

/* flags */
SELECT (SELECT SUM(t1.x + 1) FROM u) FROM t AS t1;
-- flags: F441
-- COL1: 2

/* flags */
SELECT (SELECT SUM(DISTINCT t1.x + 1) FROM u) FROM t AS t1;
-- flags: F441, F561
-- COL1: 2

/* flags */
SELECT (SELECT SUM(t1.x + u.z) FROM u) FROM t AS t1;
-- flags: F441, F442
-- COL1: 4

/* flags */
SELECT (SELECT SUM(y + z) FROM u) FROM t;
-- flags: F441, F442
-- COL1: 5

/* flags */
SELECT (SELECT SUM(t1.x + t1.y) FROM u) FROM t AS t1;
-- flags: F441, F442
-- COL1: 3

-- # The same column is one column reference only, an aggregate function of only
-- # one outer reference is allowed, and so is one that's only of its own query.

/* flags */
SELECT (SELECT SUM(t1.x) FROM u) FROM t AS t1;
-- flags:
-- COL1: 1

/* flags */
SELECT (SELECT SUM(u.x + u.z) FROM u) FROM t;
-- flags:
-- COL1: 4

/* flags */
SELECT (SELECT SUM(x + 1) FROM u) FROM t;
-- flags:
-- COL1: 2

/* flags */
SELECT SUM(x + y) FROM t;
-- flags:
-- COL1: 3

-- # ISO/IEC 9075-2:2023, 10.9, <aggregate function>, Conformance Rules, 10

/* flags */
SELECT SUM(c) FROM (SELECT COUNT(*) AS c FROM t GROUP BY x) AS d;
-- flags: F441, F591
-- COL1: 1

/* flags */
SELECT SUM(d.c + 1) FROM (SELECT COUNT(*) AS c FROM t GROUP BY x) AS d;
-- flags: F441, F591
-- COL1: 2

/* flags */
SELECT SUM(x) FROM (SELECT x, COUNT(*) AS c FROM t GROUP BY x) AS d;
-- flags: F591
-- COL1: 1

/* flags */
SELECT COUNT(*) FROM (SELECT COUNT(*) AS c FROM t) AS d;
-- flags: F591
-- COL1: 1

-- # The query of a cursor.

/* flags */
/* extensions V108-01 */
DECLARE dc CURSOR FOR SELECT SUM(c) FROM (SELECT COUNT(*) AS c FROM t GROUP BY x) AS d;
-- flags: F441, F591, V108-01
-- msg: DECLARE CURSOR

-- # ISO/IEC 9075-2:2023, 11.8, <referential constraint definition>, Conformance Rules, 5

/* flags */
CREATE TABLE c2 (a BIGINT REFERENCES p1);
-- flags: T071, T201
-- msg: CREATE TABLE 1

/* flags */
CREATE TABLE c3 (a VARCHAR(20) REFERENCES p1 (v));
-- flags: T201
-- msg: CREATE TABLE 1

/* flags */
CREATE TABLE c4 (a NUMERIC(10, 1) REFERENCES p1 (n));
-- flags: T201
-- msg: CREATE TABLE 1

/* flags */
CREATE TABLE c5 (a BIGINT, FOREIGN KEY (a) REFERENCES public.p1 (id));
-- flags: T071, T201
-- msg: CREATE TABLE 1

/* flags */
CREATE TABLE c6 (a BIGINT REFERENCES c6 (b), b INT NOT NULL UNIQUE);
-- flags: T071, T201
-- msg: CREATE TABLE 1

/* flags */
ALTER TABLE c1 ADD FOREIGN KEY (b) REFERENCES p1 (id);
-- flags: F381, T201
-- msg: ALTER TABLE 1

/* flags */
ALTER TABLE t ADD COLUMN w BIGINT REFERENCES p1;
-- flags: T071, T201
-- msg: ALTER TABLE 1

-- # The same data type (other than NOT NULL), a FOREIGN KEY that already exists
-- # with a different data type, and when the other table doesn't exist.

/* flags */
CREATE TABLE c7 (a INTEGER NOT NULL REFERENCES p1, b VARCHAR(10) REFERENCES p1 (v), c NUMERIC(10, 2) REFERENCES p1 (n));
-- flags:
-- msg: CREATE TABLE 1

/* flags */
CREATE TABLE c8 (a INT REFERENCES c8 (b), b INT NOT NULL UNIQUE);
-- flags:
-- msg: CREATE TABLE 1

/* flags */
ALTER TABLE old_key ADD FOREIGN KEY (b) REFERENCES p1 (id);
-- flags: F381
-- msg: ALTER TABLE 1

/* flags */
ALTER TABLE old_key ADD COLUMN w INT;
-- flags:
-- msg: ALTER TABLE 1

/* flags */
ALTER TABLE old_key ALTER COLUMN b DROP DEFAULT;
-- flags: F381
-- error 42601: syntax error: column B has no DEFAULT

/* flags */
ALTER TABLE missing ADD COLUMN w BIGINT REFERENCES p1;
-- flags: T071
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING

/* flags */
CREATE TABLE c9 (a BIGINT REFERENCES missing);
-- flags: T071
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING

/* flags */
CREATE TABLE c10 (a BIGINT, a BIGINT REFERENCES p1);
-- flags: T071
-- error 42601: syntax error: column A is defined more than once

-- # ISO/IEC 9075-2:2023, 14.9, <delete statement: searched>, Conformance Rules, 1.a

/* flags */
DELETE FROM t WHERE x IN (SELECT MAX(x) + 1 FROM t);
-- flags: F781
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM t WHERE x IN (SELECT a.x + 1 FROM t AS a);
-- flags: F781
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM public.t WHERE x IN (SELECT x + 1 FROM t);
-- flags: F781
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM t WHERE x IN (SELECT d.x + 1 FROM (SELECT x FROM public.t) AS d);
-- flags: F591, F781
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM t WHERE x IN (SELECT u.x + 1 FROM u JOIN t ON u.x = t.x);
-- flags: F781
-- warning 02000: no data
-- msg: DELETE 0

-- # A different table, including one of the same name in another schema, or with
-- # a correlation name that's the same as the name of the table.

/* flags */
DELETE FROM t WHERE x IN (SELECT x + 1 FROM s.t);
-- flags:
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM s.t WHERE x IN (SELECT x + 1 FROM t);
-- flags:
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM t WHERE x IN (SELECT x + 1 FROM u AS t);
-- flags:
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM t WHERE x = 0;
-- flags:
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
DELETE FROM t;
-- flags:
-- msg: DELETE 1

-- # ISO/IEC 9075-2:2023, 14.14, <update statement: searched>, Conformance Rules, 1.a
-- # ISO/IEC 9075-2:2023, 14.15, <set clause list>, Conformance Rules, 1.a

/* flags */
UPDATE t SET y = 1 WHERE x IN (SELECT x + 1 FROM t);
-- flags: F781
-- warning 02000: no data
-- msg: UPDATE 0

/* flags */
UPDATE t SET y = (SELECT MAX(x) + 1 FROM t);
-- flags: F781
-- msg: UPDATE 1

/* flags */
UPDATE t SET y = 1, x = (SELECT MAX(x) + 1 FROM public.t);
-- flags: F781
-- msg: UPDATE 1

/* flags */
UPDATE t SET y = (SELECT SUM(t.x + u.z) FROM u);
-- flags: F441, F442
-- msg: UPDATE 1

/* flags */
UPDATE t SET y = (SELECT MAX(z) FROM u);
-- flags:
-- msg: UPDATE 1

/* flags */
UPDATE t SET y = (SELECT MAX(x) FROM s.t);
-- flags:
-- msg: UPDATE 1

/* flags */
UPDATE t SET y = NULL WHERE x = 0;
-- flags:
-- warning 02000: no data
-- msg: UPDATE 0

-- # A positioned UPDATE has a <set clause list>, but no <search condition>.

/* flags */
/* extensions V113-01 */
UPDATE t SET y = (SELECT MAX(x) FROM t) WHERE CURRENT OF c1;
-- flags: F781, V113-01
-- error 34000: invalid cursor name: cursor C1 does not exist

/* flags */
/* extensions V113-01 */
UPDATE t SET y = 1 WHERE CURRENT OF c1;
-- flags: V113-01
-- error 34000: invalid cursor name: cursor C1 does not exist

-- # A dynamic parameter doesn't have a value when it's flagged, so only what comes
-- # before it is flagged.

/* flags */
DELETE FROM t WHERE x IN (SELECT x FROM t WHERE y = ?);
-- flags: B031, F781
-- error 42P02: parameter does not exist: ?1

-- # ISO/IEC 9075-2:2023, 14.11, <insert statement>, Conformance Rules, 1.a

/* flags */
INSERT INTO t SELECT x + 10, y FROM t;
-- flags: F781
-- msg: INSERT 1

/* flags */
INSERT INTO t (x) SELECT x + 1 FROM u WHERE x IN (SELECT x FROM t);
-- flags: F781
-- msg: INSERT 1

/* flags */
INSERT INTO public.t (x) SELECT x + 1 FROM t;
-- flags: F781
-- msg: INSERT 1

/* flags */
INSERT INTO t (x) SELECT d.x + 1 FROM (SELECT x FROM public.t) AS d;
-- flags: F591, F781
-- msg: INSERT 1

/* flags */
INSERT INTO t (x) SELECT u.x + 1 FROM u JOIN t ON u.x = t.x;
-- flags: F781
-- msg: INSERT 1

-- # A different table, including one of the same name in another schema, or with
-- # a correlation name that's the same as the name of the table.

/* flags */
INSERT INTO t (x) SELECT x FROM s.t;
-- flags:
-- warning 02000: no data
-- msg: INSERT 0

/* flags */
INSERT INTO s.t (x) SELECT x FROM t;
-- flags:
-- msg: INSERT 1

/* flags */
INSERT INTO t (x) SELECT t.x + 1 FROM u AS t;
-- flags:
-- msg: INSERT 1

-- # A subquery in the VALUES isn't in a <from subquery>.

/* flags */
INSERT INTO t (x) VALUES ((SELECT MAX(x) + 1 FROM t));
-- flags: F641
-- msg: INSERT 1

-- # A dynamic parameter doesn't have a value when it's flagged, so only what comes
-- # before it is flagged.

/* flags */
INSERT INTO t (x) SELECT x FROM t WHERE y = ?;
-- flags: B031, F781
-- error 42P02: parameter does not exist: ?1

-- # A statement that isn't changed by the rules.

/* flags */
INSERT INTO t (x, y) VALUES (1, 1);
-- flags:
-- msg: INSERT 1
