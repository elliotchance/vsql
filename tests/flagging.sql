-- # F812 Basic flagging: each statement is flagged with the features outside of
-- # Core SQL that it uses (PreparedStmt.features()), see the "flags" directive.
/* setup */
CREATE TABLE t (x INT NOT NULL, y VARCHAR(10), b BOOLEAN, d DATE);
INSERT INTO t (x, y, b, d) VALUES (1, 'a', TRUE, DATE '2026-10-28');
CREATE SEQUENCE seq;

/* flags */
SELECT x FROM t;
-- flags:
-- X: 1

/* flags */
SELECT x FROM t WHERE x = 1;
-- flags:
-- X: 1

/* flags */
SELECT x, y FROM t WHERE y LIKE 'a%' ESCAPE '\';
-- flags:
-- X: 1 Y: a

/* flags */
SELECT COUNT(*), COUNT(DISTINCT x), SUM(x), AVG(ALL x) FROM t;
-- flags:
-- COL1: 1 COL2: 1 COL3: 1 COL4: 1

/* flags */
SELECT x FROM t WHERE x IN (1, 2) AND x BETWEEN 1 AND 2 AND y IS NOT NULL;
-- flags:
-- X: 1

/* flags */
SELECT x FROM t WHERE EXISTS (SELECT * FROM t) AND x = ANY (SELECT x FROM t);
-- flags:
-- X: 1

/* flags */
SELECT t.* FROM t AS u (a, b2, c, e) JOIN t ON u.a = t.x ORDER BY x DESC;
-- flags:
-- X: 1 Y: a B: TRUE D: 2026-10-28

/* flags */
SELECT x FROM t GROUP BY x HAVING COUNT(*) > 0 UNION ALL SELECT x FROM t;
-- flags:
-- X: 1
-- X: 1

/* flags */
SELECT x FROM t EXCEPT SELECT x FROM t;
-- flags:

/* flags */
SELECT CASE WHEN x = 1 THEN 'a' ELSE NULLIF(y, 'b') END FROM t;
-- flags:
-- COL1: a

/* flags */
SELECT UPPER(y) || TRIM(y), CHAR_LENGTH(y), POSITION('a' IN y), SUBSTRING(y FROM 1 FOR 2) FROM t;
-- flags:
-- COL1: Aa COL2: 1 COL3: 1 COL4: a

/* flags */
SELECT CAST(x AS SMALLINT), CURRENT_DATE, LOCALTIME, LOCALTIMESTAMP FROM t;
-- flags:
-- COL1: 1 COL2: 2022-07-04 COL3: 14:05:03 COL4: 2022-07-04T14:05:03.120056

/* flags */
INSERT INTO t (x, y) VALUES (2, 'b');
-- flags:
-- msg: INSERT 1

/* flags */
UPDATE t SET y = 'c' WHERE x = 2;
-- flags:
-- warning 02000: no data
-- msg: UPDATE 0

/* flags */
DELETE FROM t WHERE x = 2;
-- flags:
-- warning 02000: no data
-- msg: DELETE 0

/* flags */
COMMIT;
-- flags:
-- error 2D000: invalid transaction termination

/* flags */
ROLLBACK WORK;
-- flags:
-- error 2D000: invalid transaction termination

/* extensions V001-01 */
/* flags */
EXPLAIN VALUES 1;
-- flags: F641, F661, V001-01
-- EXPLAIN: VALUES (COL1 SMALLINT) = ROW(1)

/* extensions V001-02 */
/* flags */
EXPLAIN DELETE FROM t WHERE x = 1;
-- flags: V001-02
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER NOT NULL, Y CHARACTER VARYING(10), B BOOLEAN, D DATE)
-- EXPLAIN: WHERE X = 1

/* extensions V001-03 */
/* flags */
EXPLAIN UPDATE t SET x = 2;
-- flags: V001-03
-- EXPLAIN: TABLE ":memory:".PUBLIC.T (X INTEGER NOT NULL, Y CHARACTER VARYING(10), B BOOLEAN, D DATE)

/* flags */
EXPLAIN COMMIT;
-- flags:
-- error 42601: syntax error: Cannot EXPLAIN COMMIT

/* flags */
SELECT TRUE, FALSE, UNKNOWN, x = 1 FROM t;
-- flags: T031
-- COL1: TRUE COL2: FALSE COL3: UNKNOWN COL4: TRUE

/* flags */
SELECT x FROM t WHERE (x = 1) IS TRUE;
-- flags: F571
-- X: 1

/* flags */
SELECT x FROM t WHERE x BETWEEN SYMMETRIC 2 AND 1;
-- flags: T461
-- X: 1

/* flags */
SELECT x FROM t WHERE y SIMILAR TO 'a';
-- flags: T141
-- X: 1

/* flags */
SELECT x FROM t WHERE x IN (1, x + 1);
-- flags: F561
-- X: 1

/* flags */
SELECT x FROM t WHERE y || 'b' LIKE 'ab';
-- flags: F281
-- X: 1

/* flags */
SELECT x FROM t WHERE y LIKE y;
-- flags: F281
-- X: 1

/* flags */
SELECT x FROM t WHERE y LIKE 'a' ESCAPE y;
-- flags: F281
-- error 22025: invalid escape sequence

/* flags */
SELECT x FROM t WHERE EXISTS (SELECT x, y FROM t);
-- flags: T501
-- X: 1

/* flags */
SELECT COUNT(x), COUNT(ALL x), COUNT(DISTINCT x + 1) FROM t;
-- flags: F441, F561
-- COL1: 1 COL2: 1 COL3: 1

/* flags */
SELECT ABS(x), MOD(x, 2), SIN(x), LOG10(x), LN(x), EXP(x), POWER(x, 2), SQRT(x), FLOOR(x), CEILING(x) FROM t;
-- flags: T441, T621, T622, T624
-- COL1: 1 COL2: 1 COL3: 0.841470984808e0 COL4: 0e0 COL5: 0e0 COL6: 2.718281828459e0 COL7: 1e0 COL8: 1e0 COL9: 1 COL10: 1

/* flags */
SELECT SUBSTRING(y FROM 1 USING CHARACTERS), CURRENT_TIME, CURRENT_TIMESTAMP(3), LOCALTIME(2), LOCALTIMESTAMP(3) FROM t;
-- flags: F411, F555, T061
-- COL1: a COL2: 14:05:03+0500 COL3: 2022-07-04T14:05:03.120+0500 COL4: 14:05:03.12 COL5: 2022-07-04T14:05:03.120

/* flags */
SELECT CURRENT_CATALOG, CURRENT_SCHEMA, NEXT VALUE FOR seq FROM t;
-- flags: F762, F763, T176
-- COL1: :memory: COL2: PUBLIC COL3: 1

/* flags */
SELECT TIME '12:00:00.5', TIME '12:00:00+05:00', TIMESTAMP '2026-10-28 12:00:00.123' FROM t;
-- flags: F411, F555
-- COL1: 12:00:00.5 COL2: 12:00:00+0500 COL3: 2026-10-28T12:00:00.123

/* flags */
SELECT CAST(x AS BIGINT), CAST(x AS BOOLEAN), CAST(d AS TIMESTAMP(3) WITH TIME ZONE), CAST(d AS TIME(1)) FROM t;
-- flags: F411, F555, T031, T071
-- error 42846: cannot coerce INTEGER to BOOLEAN

/* flags */
SELECT * FROM (SELECT x FROM t) AS u;
-- flags: F591
-- X: 1

/* flags */
SELECT x FROM t ORDER BY x OFFSET 1 ROW FETCH FIRST 1 ROW ONLY;
-- flags: F857, F861

/* flags */
SELECT x FROM t OFFSET 1.5 ROWS FETCH FIRST 2.5 ROWS ONLY;
-- flags: F857, F860, F861, F865
-- error 42601: syntax error: OFFSET row count must be an exact numeric with scale 0, got NUMERIC(2, 1)

/* flags */
SELECT (SELECT x FROM t ORDER BY x OFFSET 0 ROWS FETCH FIRST 1 ROW ONLY) FROM t;
-- flags: F850, F851, F857, F858, F861, F862
-- COL1: 1

/* flags */
SELECT ((SELECT x FROM t ORDER BY x OFFSET 0 ROWS FETCH FIRST 1 ROW ONLY)) FROM t;
-- flags: F855, F856, F863
-- COL1: 1

/* flags */
(SELECT x FROM t ORDER BY x OFFSET 0 ROWS FETCH FIRST 1 ROW ONLY) UNION SELECT x FROM t;
-- flags: F855, F856, F863
-- X: 1

/* flags */
SELECT x FROM t UNION DISTINCT SELECT x FROM t EXCEPT ALL SELECT x FROM t EXCEPT DISTINCT SELECT x FROM t;
-- flags: F304, T551

/* flags */
VALUES 1, 2;
-- flags: F641, F661
-- COL1: 1
-- COL1: 2

/* flags */
SELECT x FROM t WHERE ROW(x, y) IS NOT NULL AND (x, y) IS NOT NULL;
-- flags: F641, T051
-- X: 1

/* flags */
SELECT averylongidentifier1 FROM t AS averylongidentifier1 (averylongidentifier1, a, b, c);
-- flags: F391
-- AVERYLONGIDENTIFIER1: 1

/* flags */
SELECT "a very long delimited" FROM t AS u ("a very long delimited", a, b, c);
-- flags: F391
-- a very long delimited: 1

/* flags */
SELECT x FROM ":memory:".PUBLIC.t;
-- flags: F651
-- X: 1

/* flags */
INSERT INTO t (x, y) VALUES (2, 'b'), (3, 'c');
-- flags: F641
-- msg: INSERT 2

/* flags */
INSERT INTO t (x) VALUES 4;
-- flags: F641
-- msg: INSERT 1

/* flags */
INSERT INTO t (x, y) VALUES (5, DEFAULT);
-- flags:
-- msg: INSERT 1

/* flags */
INSERT INTO t (x) OVERRIDING USER VALUE VALUES (6);
-- flags: S043
-- error 42601: syntax error: OVERRIDING USER VALUE cannot be used without an identity column

/* flags */
START TRANSACTION;
-- flags: T241
-- msg: START TRANSACTION

/* flags */
SET CONSTRAINTS ALL DEFERRED;
-- flags: F721
-- msg: SET CONSTRAINTS

/* flags */
ROLLBACK;
-- flags:
-- error 2D000: invalid transaction termination

/* flags */
SET SCHEMA 'PUBLIC';
-- flags: F761
-- msg: SET SCHEMA 1

/* flags */
SET CATALOG ':memory:';
-- flags: F651, F761
-- msg: SET CATALOG 1

/* flags */
SELECT 'a'
  'b', U&'\0041' FROM t;
-- flags: F271, F393
-- COL1: ab COL2: A

/* flags */
SELECT x FROM t WHERE x BETWEEN ASYMMETRIC 1 AND 2;
-- flags: T461
-- X: 1

/* flags */
CREATE TABLE u (a INT UNIQUE, b INT NOT NULL UNIQUE, c INT, CONSTRAINT k PRIMARY KEY (c), CONSTRAINT f FOREIGN KEY (a) REFERENCES t (x) ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE);
-- flags: F191, F491, F701, F721, T591
-- error 42830: invalid foreign key: there is no PRIMARY KEY or UNIQUE (X) on ":memory:".PUBLIC.T

/* flags */
CREATE TABLE v (a BIGINT GENERATED ALWAYS AS IDENTITY, b INT GENERATED ALWAYS AS (a + 1), c INT CHECK (c > 0));
-- flags: T071, T174, T175
-- msg: CREATE TABLE 1

/* flags */
CREATE SCHEMA s;
-- flags: F171
-- msg: CREATE SCHEMA 1

/* flags */
DROP SCHEMA s CASCADE;
-- flags: F032, F381
-- error 3F000: invalid schema name: S

/* extensions V002-01 */
/* flags */
DROP TABLE t;
-- flags: V002-01
-- msg: DROP TABLE 1

/* flags */
DROP TABLE t CASCADE;
-- flags: F032
-- msg: DROP TABLE 1

/* flags */
ALTER TABLE t ADD COLUMN z INT;
-- flags:
-- msg: ALTER TABLE 1

/* flags */
ALTER TABLE t ALTER COLUMN y SET DEFAULT 'a';
-- flags: F381
-- msg: ALTER TABLE 1

/* flags */
ALTER TABLE t ALTER COLUMN y DROP DEFAULT;
-- flags: F381
-- error 42601: syntax error: column Y has no DEFAULT

/* extensions V002-02 */
/* flags */
ALTER TABLE t DROP COLUMN y;
-- flags: F033, V002-02
-- msg: ALTER TABLE 1

/* flags */
ALTER TABLE t DROP COLUMN y RESTRICT;
-- flags: F033
-- msg: ALTER TABLE 1

/* flags */
ALTER TABLE t ADD CONSTRAINT c CHECK (x > 0);
-- flags: F381, F491
-- msg: ALTER TABLE 1

/* extensions V002-03 */
/* flags */
ALTER TABLE t DROP CONSTRAINT c;
-- flags: F381, F491, V002-03
-- error 42704: no such constraint: C on ":memory:".PUBLIC.T

/* flags */
ALTER SEQUENCE seq RESTART;
-- flags: T176, T177
-- msg: ALTER SEQUENCE 1

/* flags */
ALTER SEQUENCE seq RESTART WITH 1;
-- flags: T176
-- msg: ALTER SEQUENCE 1

/* extensions V003-01 */
/* flags */
DROP SEQUENCE seq;
-- flags: T176, V003-01
-- msg: DROP SEQUENCE 1

/* flags */
DROP SEQUENCE seq RESTRICT;
-- flags: T176
-- msg: DROP SEQUENCE 1

/* flags */
CREATE TABLE w (a INT CHECK (a > (SELECT MIN(x) FROM t)), b DATE CHECK (b < CURRENT_DATE));
-- flags: F671, F672
-- error 42601: syntax error: a subquery cannot be used in a CHECK constraint

/* flags */
SELECT DISTINCT COUNT(DISTINCT x) FROM t;
-- flags: F801
-- COL1: 1

/* flags */
SELECT DISTINCT x FROM t WHERE x IN (SELECT DISTINCT x FROM t) ORDER BY x;
-- flags:
-- X: 1

/* flags */
SELECT x FROM t WHERE x = ?;
-- flags: B031
-- error 42P02: parameter does not exist: ?1

/* flags */
/* params 'server_version_num' */
VALUES current_setting(?);
-- sql: VALUES current_setting('server_version_num')
-- flags: B031, B033, F641, F661
-- COL1: 90310

/* flags */
SELECT x FROM t WHERE x = (1);
-- flags:
-- X: 1

/* flags */
CREATE TABLE x (a INT GENERATED BY DEFAULT AS IDENTITY);
-- flags: T174
-- msg: CREATE TABLE 1

/* flags */
ALTER TABLE x ALTER COLUMN a RESTART;
-- flags: F381, T174, T178
-- error 42P01: no such table: ":memory:".PUBLIC.X

/* flags */
ALTER TABLE x ALTER COLUMN a SET INCREMENT BY 2;
-- flags: F381, T174
-- error 42P01: no such table: ":memory:".PUBLIC.X

/* flags */
INSERT INTO t (x) VALUES (4);
-- flags:
-- msg: INSERT 1

/* flags */
INSERT INTO t (x) VALUES (4 + 1);
-- flags:
-- msg: INSERT 1

/* flags */
INSERT INTO t (x) VALUES 4 + 1;
-- flags: F641
-- msg: INSERT 1

/* flags */
INSERT INTO t (d) VALUES CURRENT_DATE;
-- flags: F641
-- error 23502: violates non-null constraint: column X

/* flags */
INSERT INTO t (x, b) VALUES (7, TRUE);
-- flags: T031
-- msg: INSERT 1

/* flags */
INSERT INTO t (x, b) VALUES (8, (TRUE));
-- flags: T031
-- msg: INSERT 1

/* flags */
INSERT INTO t (b) VALUES TRUE OR FALSE;
-- flags: F641, T031
-- error 23502: violates non-null constraint: column X

/* flags */
INSERT INTO t (b) VALUES NOT TRUE;
-- flags: F641, T031
-- error 23502: violates non-null constraint: column X

/* flags */
INSERT INTO t (b) VALUES 1 = 1;
-- flags: F641
-- error 23502: violates non-null constraint: column X

/* flags */
INSERT INTO t (b) VALUES (1 = 1);
-- flags:
-- error 23502: violates non-null constraint: column X

/* flags */
SELECT NOT b, b AND b, b OR b, b IS TRUE, (x = 1), ((x = 1)) FROM t;
-- flags: F571, T031
-- B: FALSE B: TRUE B: TRUE B: TRUE COL5: TRUE COL6: TRUE

/* flags */
SELECT COUNT(DISTINCT (x)), COUNT(DISTINCT -x), COUNT(DISTINCT x = 1), COUNT(DISTINCT (x = 1)) FROM t;
-- flags: F561, F801, T031
-- COL1: 1 COL2: 1 COL3: 1 COL4: 1

/* flags */
SELECT x FROM t WHERE x IN (1, -1, (1), x * 2) AND d IN (CURRENT_DATE, d);
-- flags: F561
-- X: 1

/* flags */
SELECT x FROM t WHERE y LIKE 'a' || 'b' OR y LIKE UPPER(y) OR (y) LIKE 'a';
-- flags: F281
-- X: 1

/* extensions V002-02 */
/* flags */
ALTER TABLE t DROP y;
-- flags: F033, V002-02
-- msg: ALTER TABLE 1

/* flags */
CREATE TABLE u (a INT NOT NULL UNIQUE, b INT REFERENCES u (a) ON UPDATE CASCADE ON DELETE CASCADE);
-- flags: F191, F701
-- msg: CREATE TABLE 1

/* flags */
SELECT CURRENT_TIME(3) FROM t WHERE y NOT LIKE 'b' ESCAPE '\';
-- flags: F411, F555
-- COL1: 14:05:03.120+0500

/* extensions V004-01 V004-02 V004-03 V004-04 V004-05 V004-06 */
/* flags */
START TRANSACTION;
DECLARE c CURSOR WITHOUT HOLD FOR SELECT * FROM t;
OPEN c;
FETCH c;
UPDATE t SET y = 'b' WHERE CURRENT OF c;
DELETE FROM t WHERE CURRENT OF c;
FETCH NEXT FROM c;
CLOSE c;
-- flags: T241
-- msg: START TRANSACTION
-- flags: T551, V004-01
-- msg: DECLARE CURSOR
-- flags: V004-02
-- msg: OPEN
-- flags: V004-03
-- X: 1 Y: a B: TRUE D: 2026-10-28
-- flags: V004-06
-- msg: UPDATE 1
-- flags: V004-05
-- msg: DELETE 1
-- flags: F431, V004-03
-- warning 02000: no data
-- flags: V004-04
-- msg: CLOSE

/* extensions V004-01 */
/* flags */
DECLARE c CURSOR FOR SELECT * FROM t ORDER BY x FOR UPDATE;
-- flags: F831, V004-01
-- msg: DECLARE CURSOR
