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
-- EXPLAIN: PRIMARY KEY PUBLIC.PK1 (PUBLIC.PK1.ID INTEGER) BETWEEN 2 AND 2
-- EXPLAIN: EXPR (ID INTEGER)

SELECT * FROM pk1 WHERE id = 2;
-- ID: 2

EXPLAIN UPDATE pk1 SET id = 5 WHERE id = 2;
-- EXPLAIN: PRIMARY KEY PUBLIC.PK1 (ID INTEGER) BETWEEN 2 AND 2

UPDATE pk1 SET id = 5 WHERE id = 2;
SELECT * FROM pk1 WHERE id = 2;
SELECT * FROM pk1 WHERE id = 5;
-- msg: UPDATE 1
-- ID: 5

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
