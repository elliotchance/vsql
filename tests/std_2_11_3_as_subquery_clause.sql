-- # CREATE TABLE ... AS (<query>) WITH DATA (T172) creates a table with the
-- # columns of the query, and inserts its rows (11.3, Syntax Rules, 10 and
-- # General Rules, 10).
CREATE TABLE t (x INT, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a'), (2, 'b');
CREATE TABLE u AS (SELECT x, y FROM t) WITH DATA;
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE TABLE 1
-- X: 1 Y: a
-- X: 2 Y: b

-- # WITH NO DATA only creates the table.
CREATE TABLE t (x INT, y VARCHAR(10));
INSERT INTO t (x, y) VALUES (1, 'a');
CREATE TABLE u AS (SELECT * FROM t) WITH NO DATA;
SELECT * FROM u;
INSERT INTO u (x, y) VALUES (3, 'c');
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 3 Y: c

-- # Each column has the type of the column of the query (Syntax Rules,
-- # 10.f.ii), and is NOT NULL only when the column of the query is known not
-- # to be null (Syntax Rules, 10.f.iii). Nothing else is copied, such as a
-- # default, a constraint or an identity column.
CREATE TABLE t (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  a NUMERIC(5, 2) DEFAULT 1.5 NOT NULL,
  b VARCHAR(20) CHECK (b <> ''),
  c TIMESTAMP(3) WITH TIME ZONE
);
CREATE TABLE u AS (SELECT * FROM t) WITH NO DATA;
/* out */
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER GENERATED ALWAYS AS IDENTITY (START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647) NOT NULL,
-- out:   "A" NUMERIC(5, 2) DEFAULT 1.5 NOT NULL,
-- out:   "B" CHARACTER VARYING(20),
-- out:   "C" TIMESTAMP(3) WITH TIME ZONE,
-- out:   PRIMARY KEY ("ID"),
-- out:   CHECK (B <> '')
-- out: );
-- out: CREATE TABLE "PUBLIC"."U" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "A" NUMERIC(5, 2) NOT NULL,
-- out:   "B" CHARACTER VARYING(20),
-- out:   "C" TIMESTAMP(3) WITH TIME ZONE
-- out: );

-- # A column of an expression has the type of the expression, and can be
-- # null.
CREATE TABLE u (a, b) AS (VALUES ROW(1 + 2, CAST('x' AS VARCHAR(5)))) WITH DATA;
/* types */
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- A: 3 (INTEGER) B: x (CHARACTER VARYING(5))

-- # The <column name list> names the columns (Syntax Rules, 10.f.i).
CREATE TABLE u (p, q) AS (VALUES (1, 'a')) WITH DATA;
SELECT p, q FROM u;
-- msg: CREATE TABLE 1
-- P: 1 Q: a

-- # It must have one name for each column of the query (Syntax Rules, 10.e),
-- # and each name only once (Syntax Rules, 10.d).
CREATE TABLE u (p) AS (VALUES (1, 'a')) WITH DATA;
-- error 42601: syntax error: CREATE TABLE has 1 column names, but the query has 2 columns

CREATE TABLE u (p, q, r) AS (VALUES (1, 'a')) WITH DATA;
-- error 42601: syntax error: CREATE TABLE has 3 column names, but the query has 2 columns

CREATE TABLE u (p, p) AS (VALUES (1, 'a')) WITH DATA;
-- error 42601: syntax error: column P is defined more than once

-- # Without a <column name list>, each column of the query must have a name
-- # that isn't implementation-dependent, and the names must be different
-- # (Syntax Rules, 10.b).
CREATE TABLE u AS (VALUES (1, 'a')) WITH DATA;
-- error 42601: syntax error: column 1 of the query needs a name, or a column name list is needed

CREATE TABLE t (x INT);
CREATE TABLE u AS (SELECT x AS a, 2 FROM t) WITH DATA;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column 2 of the query needs a name, or a column name list is needed

CREATE TABLE t (x INT);
CREATE TABLE u AS (SELECT x, x FROM t) WITH NO DATA;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: column X is defined more than once

CREATE TABLE t (x INT);
CREATE TABLE u (a, b) AS (SELECT x, x FROM t) WITH NO DATA;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1

-- # The query can use any table, but not the new one, which doesn't exist yet
-- # (Syntax Rules, 16).
CREATE TABLE u AS (SELECT * FROM u) WITH DATA;
-- error 42P01: no such table: ":memory:".PUBLIC.U

-- # A parameter can't be used (Syntax Rules, 4).
CREATE TABLE t (x INT);
/* params 1 */
CREATE TABLE u AS (SELECT x, ? AS y FROM t) WITH DATA;
-- msg: CREATE TABLE 1
-- sql: CREATE TABLE u AS (SELECT x, 1.0e0 AS y FROM t) WITH DATA
-- error 42601: syntax error: parameter ?1 cannot be used in CREATE TABLE

-- # The table must not exist already (Syntax Rules, 7).
CREATE TABLE t (x INT);
CREATE TABLE t AS (SELECT * FROM t) WITH DATA;
-- msg: CREATE TABLE 1
-- error 42P07: duplicate table: ":memory:".PUBLIC.T

-- # An empty query creates an empty table, and the INSERT of its rows warns that
-- # there's no data, like any other INSERT.
CREATE TABLE t (x INT);
CREATE TABLE u AS (SELECT * FROM t) WITH DATA;
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- warning 02000: no data
-- msg: CREATE TABLE 1

-- # The query can have an ORDER BY and FETCH FIRST, like a subquery.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (3), (1), (2);
CREATE TABLE u AS (SELECT x FROM t ORDER BY x FETCH FIRST 2 ROWS ONLY) WITH DATA;
SELECT * FROM u ORDER BY x;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: CREATE TABLE 1
-- X: 1
-- X: 2

-- # IF NOT EXISTS (V103-01) works the same way: the query isn't used when the
-- # table exists, so it isn't checked either.
/* extensions V103-01 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (5);
CREATE TABLE IF NOT EXISTS u AS (SELECT * FROM t) WITH DATA;
CREATE TABLE IF NOT EXISTS t AS (SELECT * FROM nosuch) WITH DATA;
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 0
-- X: 5

-- # It can be in a CREATE SCHEMA.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (7);
CREATE SCHEMA s CREATE TABLE u AS (SELECT x FROM public.t) WITH DATA;
SELECT * FROM s.u;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE SCHEMA 1
-- X: 7

-- # The <as subquery clause> is flagged with T172.
CREATE TABLE t (x INT);
/* flags */
CREATE TABLE u AS (SELECT x FROM t) WITH DATA;
-- flags:
-- msg: CREATE TABLE 1
-- flags: T172
-- warning 02000: no data
-- msg: CREATE TABLE 1

-- # And with the flags of a subquery.
CREATE TABLE t (x INT);
/* flags */
CREATE TABLE u AS (SELECT x FROM t ORDER BY x) WITH NO DATA;
-- flags:
-- msg: CREATE TABLE 1
-- flags: F850, F851, T172
-- msg: CREATE TABLE 1

-- # Leaving out the parentheses (V103-02) or WITH DATA (V103-03) is flagged
-- # too.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
/* flags */
/* extensions V103-02 V103-03 */
CREATE TABLE u AS SELECT x FROM t WITH NO DATA;
CREATE TABLE v AS (SELECT x FROM t);
-- flags:
-- msg: CREATE TABLE 1
-- flags:
-- msg: INSERT 1
-- flags: T172, V103-02
-- msg: CREATE TABLE 1
-- flags: T172, V103-03
-- msg: CREATE TABLE 1

-- # A query without parentheses is a vsql extension (V103-02), and so is no
-- # WITH DATA or WITH NO DATA (V103-03), which is the same as WITH DATA.
/* extensions V103-02 V103-03 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
CREATE TABLE u AS SELECT x FROM t;
CREATE TABLE v (y) AS SELECT x FROM t WITH NO DATA;
CREATE TABLE w AS (SELECT x FROM t);
CREATE TABLE z (y) AS (SELECT x FROM t);
SELECT * FROM u;
SELECT * FROM v;
SELECT * FROM w;
SELECT * FROM z;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- X: 1
-- X: 1
-- Y: 1

/* extensions V103-02 */
CREATE TABLE u AS VALUES 1 WITH DATA;
-- error 42601: syntax error: column 1 of the query needs a name, or a column name list is needed

-- # A query without parentheses can still start with a parenthesized query.
/* extensions V103-02 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
CREATE TABLE u AS (SELECT x FROM t WHERE x = 1) UNION (SELECT x FROM t WHERE x = 2) WITH DATA;
SELECT * FROM u ORDER BY x;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE TABLE 1
-- X: 1
-- X: 2

-- # A WITH after a TIME or TIMESTAMP type is always WITH TIME ZONE, so a query
-- # that ends in one needs parentheses before WITH DATA.
CREATE TABLE t (x TIME);
CREATE TABLE u AS SELECT x::TIME FROM t WHERE x::TIME WITH DATA;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unexpected DATA at line 1, column 60 near "::TIME WITH DATA", expecting TIME

/* extensions V303-01 */
CREATE TABLE t (x TIME);
INSERT INTO t (x) VALUES (TIME '12:00:00');
CREATE TABLE u AS (SELECT x::TIME AS y FROM t) WITH DATA;
SELECT * FROM u;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE TABLE 1
-- Y: 12:00:00
