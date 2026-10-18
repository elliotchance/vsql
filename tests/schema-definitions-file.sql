/* connection 1 */
CREATE SCHEMA "Mixed";
CREATE TABLE "Mixed"."Tab" ("lower" INT, "SELECT" VARCHAR(10), c CHAR, d CHARACTER(3), t TIMESTAMP, z TIME(3) WITH TIME ZONE, f FLOAT, r REAL, n NUMERIC(10, 2), dd DECIMAL(5), b BOOLEAN, x SMALLINT NOT NULL, y BIGINT, dp DOUBLE PRECISION, dt DATE, tz TIMESTAMP(2) WITH TIME ZONE, PRIMARY KEY (y));
INSERT INTO "Mixed"."Tab" ("lower", "SELECT", c, d, x, y, n, t, tz, b, dd) VALUES (1, 'a', 'b', 'cde', 3, 4, 12.34, TIMESTAMP '2020-01-02 03:04:05', TIMESTAMP '2020-01-02 03:04:05.12+05:00', TRUE, 12345);
/* connection 2 */
SELECT * FROM "Mixed"."Tab";
EXPLAIN SELECT * FROM "Mixed"."Tab" WHERE y = 4;
INSERT INTO "Mixed"."Tab" (y) VALUES (5);
INSERT INTO "Mixed"."Tab" (x, y, "SELECT") VALUES (1, 6, 'abcdefghijk');
INSERT INTO "Mixed"."Tab" (x, y, c) VALUES (1, 6, 'ab');
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: lower: 1 SELECT: a C: b D: cde T: 2020-01-02T03:04:05 Z: NULL F: NULL R: NULL N: 12.34 DD: 12345 B: TRUE X: 3 Y: 4 DP: NULL DT: NULL TZ: 2020-01-02T03:04:05.12+0500
-- 2: EXPLAIN: PRIMARY KEY "Mixed"."Tab" ("lower" INTEGER, SELECT CHARACTER VARYING(10), C CHARACTER(1), D CHARACTER(3), T TIMESTAMP(0) WITHOUT TIME ZONE, Z TIME(3) WITH TIME ZONE, F DOUBLE PRECISION, R REAL, N NUMERIC(10, 2), DD DECIMAL(5), B BOOLEAN, X SMALLINT NOT NULL, Y BIGINT, DP DOUBLE PRECISION, DT DATE, TZ TIMESTAMP(2) WITH TIME ZONE) BETWEEN 4 AND 4
-- 2: EXPLAIN: EXPR ("test"."Mixed"."Tab"."lower" INTEGER, "test"."Mixed"."Tab".SELECT CHARACTER VARYING(10), "test"."Mixed"."Tab".C CHARACTER(1), "test"."Mixed"."Tab".D CHARACTER(3), "test"."Mixed"."Tab".T TIMESTAMP(0) WITHOUT TIME ZONE, "test"."Mixed"."Tab".Z TIME(3) WITH TIME ZONE, "test"."Mixed"."Tab".F DOUBLE PRECISION, "test"."Mixed"."Tab".R REAL, "test"."Mixed"."Tab".N NUMERIC(10, 2), "test"."Mixed"."Tab".DD DECIMAL(5), "test"."Mixed"."Tab".B BOOLEAN, "test"."Mixed"."Tab".X SMALLINT NOT NULL, "test"."Mixed"."Tab".Y BIGINT, "test"."Mixed"."Tab".DP DOUBLE PRECISION, "test"."Mixed"."Tab".DT DATE, "test"."Mixed"."Tab".TZ TIMESTAMP(2) WITH TIME ZONE)
-- 2: error 23502: violates non-null constraint: column "test"."Mixed"."Tab".X
-- 2: error 22001: string data right truncation for CHARACTER VARYING(10)
-- 2: error 22001: string data right truncation for CHARACTER(1)

/* connection 1 */
CREATE SCHEMA "Mixed";
CREATE SEQUENCE "Mixed"."seq" INCREMENT BY -2 MINVALUE -50 MAXVALUE 100 CYCLE;
CREATE SEQUENCE plain START WITH 7;
VALUES NEXT VALUE FOR "Mixed"."seq";
/* connection 2 */
VALUES NEXT VALUE FOR "Mixed"."seq";
ALTER SEQUENCE "Mixed"."seq" INCREMENT BY 50;
/* connection 1 */
VALUES NEXT VALUE FOR "Mixed"."seq";
VALUES NEXT VALUE FOR "Mixed"."seq";
VALUES NEXT VALUE FOR plain;
DROP SEQUENCE "Mixed"."seq";
/* connection 2 */
VALUES NEXT VALUE FOR "Mixed"."seq";
-- 1: msg: CREATE SCHEMA 1
-- 1: msg: CREATE SEQUENCE 1
-- 1: msg: CREATE SEQUENCE 1
-- 1: COL1: 100
-- 2: COL1: 98
-- 2: msg: ALTER SEQUENCE 1
-- 1: COL1: -50
-- 1: COL1: 0
-- 1: COL1: 7
-- 1: msg: DROP SEQUENCE 1
-- 2: error 42P01: no such sequence: "test"."Mixed"."seq"
