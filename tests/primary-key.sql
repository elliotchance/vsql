/* setup */
CREATE TABLE pk1 (
    id INT,
    PRIMARY KEY (id)
);
INSERT INTO pk1 (id) VALUES (1);
INSERT INTO pk1 (id) VALUES (2);
INSERT INTO pk1 (id) VALUES (3);

SELECT * FROM pk1;
-- ID: 1
-- ID: 2
-- ID: 3

EXPLAIN SELECT * FROM pk1 WHERE id = 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.PK1 (ID INTEGER NOT NULL) BETWEEN 2 AND 2
-- EXPLAIN: EXPR (":memory:".PUBLIC.PK1.ID INTEGER NOT NULL)

SELECT * FROM pk1 WHERE id = 2;
-- ID: 2

EXPLAIN UPDATE pk1 SET id = 5 WHERE id = 2;
-- EXPLAIN: PRIMARY KEY ":memory:".PUBLIC.PK1 (ID INTEGER NOT NULL) BETWEEN 2 AND 2

UPDATE pk1 SET id = 5 WHERE id = 2;
SELECT * FROM pk1 WHERE id = 2;
SELECT * FROM pk1 WHERE id = 5;
-- msg: UPDATE 1
-- ID: 5

INSERT INTO pk1 (id) VALUES (2);
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PK1

INSERT INTO pk1 (id) VALUES (NULL);
-- error 23502: violates non-null constraint: column ID

CREATE TABLE pk2 (id INT, x INT, PRIMARY KEY (id));
INSERT INTO pk2 (x) VALUES (1);
-- msg: CREATE TABLE 1
-- error 23502: violates non-null constraint: column ":memory:".PUBLIC.PK2.ID

UPDATE pk1 SET id = 3 WHERE id = 2;
SELECT * FROM pk1;
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PK1
-- ID: 1
-- ID: 2
-- ID: 3

UPDATE pk1 SET id = NULL WHERE id = 2;
-- error 23502: violates non-null constraint: column ID

CREATE TABLE pk2 (id INT, x INT, PRIMARY KEY (id));
INSERT INTO pk2 (id, x) VALUES (1, 10);
UPDATE pk2 SET x = 20 WHERE id = 1;
SELECT * FROM pk2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- ID: 1 X: 20

DELETE FROM pk1 WHERE id = 2;
INSERT INTO pk1 (id) VALUES (2);
SELECT * FROM pk1;
-- msg: DELETE 1
-- msg: INSERT 1
-- ID: 1
-- ID: 2
-- ID: 3

START TRANSACTION;
DELETE FROM pk1 WHERE id = 2;
INSERT INTO pk1 (id) VALUES (2);
INSERT INTO pk1 (id) VALUES (2);
-- msg: START TRANSACTION
-- msg: DELETE 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PK1

/* connection 1 */
CREATE TABLE pk3 (id INT, PRIMARY KEY (id));
INSERT INTO pk3 (id) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO pk3 (id) VALUES (2);
/* connection 2 */
INSERT INTO pk3 (id) VALUES (2);
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row

/* connection 1 */
CREATE TABLE pk3 (id INT, PRIMARY KEY (id));
INSERT INTO pk3 (id) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
DELETE FROM pk3 WHERE id = 1;
/* connection 2 */
INSERT INTO pk3 (id) VALUES (1);
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: DELETE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row

CREATE TABLE pk2 (id SMALLINT, PRIMARY KEY (id));
INSERT INTO pk2 (id) VALUES (3);
INSERT INTO pk2 (id) VALUES (-1);
INSERT INTO pk2 (id) VALUES (32767);
INSERT INTO pk2 (id) VALUES (0);
INSERT INTO pk2 (id) VALUES (-32768);
SELECT * FROM pk2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- ID: -32768
-- ID: -1
-- ID: 0
-- ID: 3
-- ID: 32767

CREATE TABLE pk2 (id INTEGER, PRIMARY KEY (id));
INSERT INTO pk2 (id) VALUES (3);
INSERT INTO pk2 (id) VALUES (-1);
INSERT INTO pk2 (id) VALUES (2147483647);
INSERT INTO pk2 (id) VALUES (0);
INSERT INTO pk2 (id) VALUES (-2147483648);
SELECT * FROM pk2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- ID: -2147483648
-- ID: -1
-- ID: 0
-- ID: 3
-- ID: 2147483647

CREATE TABLE pk2 (id BIGINT, PRIMARY KEY (id));
INSERT INTO pk2 (id) VALUES (3);
INSERT INTO pk2 (id) VALUES (-1);
INSERT INTO pk2 (id) VALUES (9223372036854775807);
INSERT INTO pk2 (id) VALUES (0);
INSERT INTO pk2 (id) VALUES (-9223372036854775808);
SELECT * FROM pk2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- ID: -9223372036854775808
-- ID: -1
-- ID: 0
-- ID: 3
-- ID: 9223372036854775807

CREATE TABLE pk2 (
    PRIMARY KEY (id),
    id INT
);
-- msg: CREATE TABLE 1

CREATE TABLE pk2 (
    id SMALLINT,
    PRIMARY KEY (id)
);
-- msg: CREATE TABLE 1

CREATE TABLE pk2 (
    id BIGINT,
    PRIMARY KEY (id)
);
-- msg: CREATE TABLE 1

CREATE TABLE pk2 (
    id INT,
    PRIMARY KEY (id),
    PRIMARY KEY (id)
);
-- error 42601: syntax error: only one PRIMARY KEY can be defined

CREATE TABLE pk2 (
    id INT,
    PRIMARY KEY (id, id)
);
-- error 42601: syntax error: column ID appears more than once in PRIMARY KEY

CREATE TABLE pk2 (a INT, b SMALLINT, x INT, PRIMARY KEY (a, b));
INSERT INTO pk2 (a, b, x) VALUES (1, 2, 10);
INSERT INTO pk2 (a, b, x) VALUES (-1, 5, 20);
INSERT INTO pk2 (a, b, x) VALUES (1, -3, 30);
INSERT INTO pk2 (a, b, x) VALUES (0, 0, 40);
INSERT INTO pk2 (a, b, x) VALUES (1, 2, 50);
INSERT INTO pk2 (a, b, x) VALUES (1, NULL, 60);
UPDATE pk2 SET b = 2 WHERE x = 30;
UPDATE pk2 SET a = 2 WHERE x = 30;
SELECT * FROM pk2;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PK2
-- error 23502: violates non-null constraint: column B
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PK2
-- msg: UPDATE 1
-- A: -1 B: 5 X: 20
-- A: 0 B: 0 X: 40
-- A: 1 B: 2 X: 10
-- A: 2 B: -3 X: 30

/* connection 1 */
CREATE TABLE pk3 (a INT, b BIGINT, PRIMARY KEY (a, b));
INSERT INTO pk3 (a, b) VALUES (1, 2);
INSERT INTO pk3 (a, b) VALUES (1, -2);
/* connection 2 */
INSERT INTO pk3 (a, b) VALUES (1, 2);
SELECT * FROM pk3;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: INSERT 1
-- 2: error 23505: violates unique constraint: PRIMARY KEY on "test".PUBLIC.PK3
-- 2: A: 1 B: -2
-- 2: A: 1 B: 2

CREATE TABLE pk2 (b INT, a INT, PRIMARY KEY (a, b));
INSERT INTO pk2 (a, b) VALUES (1, 2);
INSERT INTO pk2 (a, b) VALUES (2, 1);
INSERT INTO pk2 (a, b) VALUES (1, 1);
EXPLAIN SELECT * FROM pk2 WHERE a = 1;
SELECT * FROM pk2 WHERE a = 1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- EXPLAIN: TABLE ":memory:".PUBLIC.PK2 (B INTEGER NOT NULL, A INTEGER NOT NULL)
-- EXPLAIN: WHERE A = 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.PK2.B INTEGER NOT NULL, ":memory:".PUBLIC.PK2.A INTEGER NOT NULL)
-- B: 1 A: 1
-- B: 2 A: 1

CREATE TABLE pk2 (
    id INT,
    PRIMARY KEY (foo)
);
-- error 42601: syntax error: unknown column FOO in PRIMARY KEY
