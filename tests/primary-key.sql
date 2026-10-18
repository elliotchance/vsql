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
START TRANSACTION;
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
START TRANSACTION;
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
    id2 INT,
    PRIMARY KEY (id, id2)
);
-- error 42601: syntax error: PRIMARY KEY only supports one column

CREATE TABLE pk2 (
    id INT,
    PRIMARY KEY (foo)
);
-- error 42601: syntax error: unknown column FOO in PRIMARY KEY

CREATE TABLE pk2 (
    id BOOLEAN,
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support BOOLEAN

CREATE TABLE pk2 (
    id DOUBLE PRECISION,
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support DOUBLE PRECISION

CREATE TABLE pk2 (
    id FLOAT,
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support DOUBLE PRECISION

CREATE TABLE pk2 (
    id REAL,
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support REAL

CREATE TABLE pk2 (
    id CHARACTER VARYING(10),
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support CHARACTER VARYING(10)

CREATE TABLE pk2 (
    id VARCHAR(12),
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support CHARACTER VARYING(12)

CREATE TABLE pk2 (
    id CHARACTER(36),
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support CHARACTER(36)

CREATE TABLE pk2 (
    id CHARACTER,
    PRIMARY KEY (id)
);
-- error 42601: syntax error: PRIMARY KEY does not support CHARACTER(1)
