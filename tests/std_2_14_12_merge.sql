/* setup */
CREATE TABLE t (id INT PRIMARY KEY, name VARCHAR(10), n INT);
CREATE TABLE s (id INT, name VARCHAR(10), n INT);
INSERT INTO t (id, name, n) VALUES (1, 'a', 10);
INSERT INTO t (id, name, n) VALUES (2, 'b', 20);
INSERT INTO s (id, name, n) VALUES (2, 'B', 5);
INSERT INTO s (id, name, n) VALUES (3, 'c', 30);

-- # A row of the source that matches a row of the target updates it, and a
-- # row that doesn't match is inserted (General Rules, 6). The count is both.
/* flags */
MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = t.n + s.n, name = s.name
WHEN NOT MATCHED THEN INSERT VALUES (s.id, s.name, s.n);
SELECT * FROM t;
-- flags: F312
-- msg: MERGE 2
-- flags:
-- ID: 1 NAME: a N: 10
-- ID: 2 NAME: B N: 25
-- ID: 3 NAME: c N: 30

-- # The source can be a derived table, and the target can have a correlation
-- # name, which is then the only name of the target (Syntax Rules, 8 and 9).
MERGE INTO t AS x USING (VALUES (1, 100)) AS v (id, n) ON x.id = v.id
WHEN MATCHED THEN UPDATE SET n = x.n + v.n;
SELECT * FROM t;
MERGE INTO t AS x USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = 1;
-- msg: MERGE 1
-- ID: 1 NAME: a N: 110
-- ID: 2 NAME: b N: 20
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.ID

-- # A row of the target can only be matched by one row of the source (General
-- # Rules, 6.a.i.1.B.II), and nothing is changed.
MERGE INTO t USING (VALUES 2, 2) AS v (id) ON t.id = v.id
WHEN MATCHED THEN UPDATE SET n = 0;
SELECT * FROM t;
-- error 21000: cardinality violation: more than one row of the source matches the same row of ":memory:".PUBLIC.T
-- ID: 1 NAME: a N: 10
-- ID: 2 NAME: b N: 20

-- # Without a <merge when not matched clause>, a row of the source that
-- # doesn't match is left out, and without a <merge when matched clause> so is
-- # a row that matches. A row that matches, but whose values don't change
-- # (including a NULL that stays NULL), is still counted.
MERGE INTO t USING s ON t.id = s.id WHEN MATCHED THEN UPDATE SET n = 20;
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id, n) VALUES (s.id + 10, s.n);
MERGE INTO t USING (VALUES 13) AS v (id) ON t.id = v.id
WHEN MATCHED THEN UPDATE SET name = NULL;
SELECT * FROM t;
-- msg: MERGE 1
-- msg: MERGE 1
-- msg: MERGE 1
-- ID: 1 NAME: a N: 10
-- ID: 2 NAME: b N: 20
-- ID: 13 NAME: NULL N: 30

-- # Only the first clause of each kind is used (several of either kind need
-- # Feature F313).
/* flags */
MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = 1
WHEN MATCHED THEN UPDATE SET n = 2
WHEN NOT MATCHED THEN INSERT (id) VALUES (s.id)
WHEN NOT MATCHED THEN INSERT (id) VALUES (s.id + 1);
SELECT * FROM t;
-- flags: F312, F313
-- msg: MERGE 2
-- flags:
-- ID: 1 NAME: a N: 10
-- ID: 2 NAME: b N: 1
-- ID: 3 NAME: NULL N: NULL

-- # An empty source is no data (General Rules, 7).
MERGE INTO t USING (SELECT * FROM s WHERE id > 99) AS v ON t.id = v.id
WHEN MATCHED THEN UPDATE SET n = 0;
-- warning 02000: no data
-- msg: MERGE 0

-- # The new key of an updated row can be the old key of another (the
-- # PRIMARY KEY is checked once every row has changed), and an inserted row
-- # can have the key that an updated row had.
MERGE INTO t USING (VALUES 1, 2, 3) AS v (id) ON t.id = v.id
WHEN MATCHED THEN UPDATE SET id = t.id + 1
WHEN NOT MATCHED THEN INSERT (id, name) VALUES (v.id - 2, 'new');
SELECT * FROM t;
-- msg: MERGE 3
-- ID: 1 NAME: new N: NULL
-- ID: 2 NAME: a N: 10
-- ID: 3 NAME: b N: 20

-- # The constraints are checked like an UPDATE and an INSERT.
MERGE INTO t USING s ON t.name = s.name
WHEN NOT MATCHED THEN INSERT (id, n) VALUES (1, s.n);
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id) VALUES (NULL);
MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET id = NULL;
SELECT * FROM t;
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
-- error 23502: violates non-null constraint: column ID
-- error 23502: violates non-null constraint: column ID
-- ID: 1 NAME: a N: 10
-- ID: 2 NAME: b N: 20

-- # Each column can only be set once, and only be in an <insert column list>
-- # once (Syntax Rules, 19). The values of an INSERT can only reference the
-- # source (Syntax Rules, 9), and a value must be assignable to its column.
MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = 1, n = 2;
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id, id) VALUES (1, 2);
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id) VALUES (t.id);
MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = 'x';
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id, n) VALUES (s.id, 'x');
-- error 42601: syntax error: column N is set more than once
-- error 42601: syntax error: column ID is specified more than once
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.T.ID
-- error 42846: cannot coerce CHARACTER(1) to INTEGER
-- error 42846: cannot coerce CHARACTER(1) to INTEGER

-- # The names are found when the MERGE is prepared.
MERGE INTO nope USING s ON nope.id = s.id
WHEN MATCHED THEN UPDATE SET n = 1;
MERGE INTO t USING nope ON t.id = nope.id
WHEN MATCHED THEN UPDATE SET n = 1;
MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET nope = 1;
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (nope) VALUES (1);
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE
-- error 42P01: no such table: ":memory:".PUBLIC.NOPE
-- error 42703: no such column: NOPE
-- error 42703: no such column: NOPE

-- # A generated column, and a GENERATED ALWAYS identity column, can only be
-- # DEFAULT, even when no row matches. An <override clause> needs an identity
-- # column, and an INSERT has a value for each column (Syntax Rules, 14 and 20).
CREATE TABLE g (id INT GENERATED ALWAYS AS IDENTITY, x INT, y INT GENERATED ALWAYS AS (x * 2));
INSERT INTO g (x) VALUES (1);
MERGE INTO g USING s ON g.x = s.id
WHEN NOT MATCHED THEN INSERT (id, x, y) VALUES (DEFAULT, s.id, DEFAULT);
MERGE INTO g USING s ON g.x = s.id
WHEN MATCHED THEN UPDATE SET x = 1, y = DEFAULT, id = DEFAULT;
SELECT * FROM g;
MERGE INTO g USING s ON g.x = s.id
WHEN MATCHED THEN UPDATE SET y = 1;
MERGE INTO g USING s ON g.x = s.id
WHEN NOT MATCHED THEN INSERT (id, x) VALUES (9, s.id);
MERGE INTO g USING s ON g.x = s.id
WHEN NOT MATCHED THEN INSERT (x, y) VALUES (s.id, 9);
MERGE INTO g USING s ON g.x = s.id
WHEN NOT MATCHED THEN INSERT (id, x) OVERRIDING SYSTEM VALUE VALUES (9, s.id);
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id) OVERRIDING USER VALUE VALUES (s.id);
MERGE INTO t USING s ON t.id = s.id
WHEN NOT MATCHED THEN INSERT (id, n) VALUES (s.id);
SELECT * FROM g;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: MERGE 2
-- msg: MERGE 2
-- ID: 1 X: 1 Y: 2
-- ID: 4 X: 1 Y: 2
-- ID: 5 X: 1 Y: 2
-- error 428C9: cannot assign a value other than DEFAULT to column Y, which is GENERATED ALWAYS
-- error 428C9: cannot assign a value other than DEFAULT to column ID, which is GENERATED ALWAYS
-- error 428C9: cannot assign a value other than DEFAULT to column Y, which is GENERATED ALWAYS
-- msg: MERGE 2
-- error 42601: syntax error: OVERRIDING USER VALUE cannot be used without an identity column
-- error 42601: syntax error: INSERT has less values than columns
-- ID: 1 X: 1 Y: 2
-- ID: 4 X: 1 Y: 2
-- ID: 5 X: 1 Y: 2
-- ID: 9 X: 2 Y: 4
-- ID: 9 X: 3 Y: 6

-- # A CHECK constraint, and a FOREIGN KEY, are checked for each new row.
CREATE TABLE c (id INT PRIMARY KEY, x INT CHECK (x > 0), p INT REFERENCES t (id));
MERGE INTO c USING s ON c.id = s.id
WHEN NOT MATCHED THEN INSERT (id, x) VALUES (s.id, 0 - s.n);
MERGE INTO c USING s ON c.id = s.id
WHEN NOT MATCHED THEN INSERT (id, x, p) VALUES (s.id, s.n, 99);
MERGE INTO c USING s ON c.id = s.id
WHEN NOT MATCHED THEN INSERT (id, x, p) VALUES (s.id, s.n, 1);
MERGE INTO c USING s ON c.id = s.id
WHEN MATCHED THEN UPDATE SET x = 0;
MERGE INTO c USING s ON c.id = s.id
WHEN MATCHED THEN UPDATE SET p = 99;
-- msg: CREATE TABLE 1
-- error 23514: violates check constraint: CHECK (X > 0) on ":memory:".PUBLIC.C
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.T (ID) on ":memory:".PUBLIC.C
-- msg: MERGE 2
-- error 23514: violates check constraint: CHECK (X > 0) on ":memory:".PUBLIC.C
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.T (ID) on ":memory:".PUBLIC.C

-- # A PRIMARY KEY (or index) of the target finds the row that each row of the
-- # source matches.
/* extensions V001-04 */
EXPLAIN MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = 1;
-- EXPLAIN: $1:
-- EXPLAIN:   TABLE ":memory:".PUBLIC.S (ID INTEGER, NAME CHARACTER VARYING(10), N INTEGER)
-- EXPLAIN: $2:
-- EXPLAIN:   PRIMARY KEY ":memory:".PUBLIC.T (ID INTEGER NOT NULL, NAME CHARACTER VARYING(10), N INTEGER) RANGE T.ID = S.ID
-- EXPLAIN: LEFT JOIN ON T.ID = S.ID (":memory:".PUBLIC.S.ID INTEGER, ":memory:".PUBLIC.S.NAME CHARACTER VARYING(10), ":memory:".PUBLIC.S.N INTEGER, ":memory:".PUBLIC.T.ID INTEGER, ":memory:".PUBLIC.T.NAME CHARACTER VARYING(10), ":memory:".PUBLIC.T.N INTEGER)

-- # The source can't be a joined table, and can't have the same name as the
-- # target (Syntax Rules, 11 and 12).
MERGE INTO t USING s JOIN s AS s2 ON s.id = s2.id ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = 1;
MERGE INTO t USING t ON t.id = t.id
WHEN MATCHED THEN UPDATE SET n = 1;
MERGE INTO t USING s AS t ON t.id = t.id
WHEN MATCHED THEN UPDATE SET n = 1;
-- error 42601: syntax error: unexpected JOIN at line 1, column 22 near "t USING s JOIN s", expecting ON
-- error 42601: syntax error: table name ":memory:".PUBLIC.T specified more than once
-- error 42601: syntax error: table name T specified more than once

-- # A MERGE can't be in a READ ONLY transaction (General Rules, 1).
START TRANSACTION READ ONLY;
MERGE INTO t USING s ON t.id = s.id
WHEN MATCHED THEN UPDATE SET n = 1;
ROLLBACK;
-- msg: START TRANSACTION
-- error 25006: read-only sql transaction: cannot execute MERGE
-- msg: ROLLBACK

-- # A GENERATED BY DEFAULT identity column can be given a value, and only
-- # OVERRIDING USER VALUE can be used for it (Syntax Rules, 14.c).
CREATE TABLE d (id INT GENERATED BY DEFAULT AS IDENTITY, x INT);
MERGE INTO d USING s ON d.x = s.id
WHEN NOT MATCHED THEN INSERT (id, x) VALUES (s.id * 10, s.id);
MERGE INTO d USING s ON d.x = s.n
WHEN NOT MATCHED THEN INSERT OVERRIDING USER VALUE VALUES (99, s.n);
MERGE INTO d USING s ON d.x = s.n
WHEN NOT MATCHED THEN INSERT (id, x) OVERRIDING SYSTEM VALUE VALUES (99, s.n);
SELECT * FROM d;
-- msg: CREATE TABLE 1
-- msg: MERGE 2
-- msg: MERGE 2
-- error 42601: syntax error: OVERRIDING SYSTEM VALUE cannot be used for identity column ID, which is GENERATED BY DEFAULT
-- ID: 20 X: 2
-- ID: 30 X: 3
-- ID: 1 X: 5
-- ID: 2 X: 30

-- # A source that's a query that reads the target, or a subquery of the
-- # condition that does, needs Feature F781, but the target itself as the
-- # source doesn't (Conformance Rules, 1.a and 2.a).
/* flags */
MERGE INTO t USING (SELECT id FROM t) AS v ON t.id = v.id
WHEN MATCHED THEN UPDATE SET n = 1;
MERGE INTO t USING t AS v ON t.id = v.id
WHEN MATCHED THEN UPDATE SET n = 2;
MERGE INTO t USING s ON t.id = (SELECT MAX(id) FROM t) AND s.id = 2
WHEN MATCHED THEN UPDATE SET n = 3;
-- flags: F312, F591, F781
-- msg: MERGE 2
-- flags: F312
-- msg: MERGE 2
-- flags: F312, F781
-- msg: MERGE 1
