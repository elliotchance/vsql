-- # ON UPDATE CASCADE changes the referencing columns to the new values of the
-- # referenced columns, and the rows that reference those rows, and so on. A row
-- # that keeps its key, or changes other columns, doesn't change.
CREATE TABLE parent (id INT PRIMARY KEY, name VARCHAR(10));
CREATE TABLE child (id INT PRIMARY KEY, parent_id BIGINT REFERENCES parent ON UPDATE CASCADE);
CREATE TABLE grandchild (child_id INT, FOREIGN KEY (child_id) REFERENCES child (id) ON UPDATE CASCADE);
INSERT INTO parent (id, name) VALUES (1, 'a'), (2, 'b');
INSERT INTO child (id, parent_id) VALUES (10, 1), (20, 2), (30, NULL);
INSERT INTO grandchild (child_id) VALUES (10), (20), (NULL);
UPDATE parent SET name = 'c';
UPDATE parent SET id = id + 1 WHERE id = 1;
SELECT * FROM child;
UPDATE child SET id = id * 10;
SELECT * FROM grandchild;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 3
-- msg: INSERT 3
-- msg: UPDATE 2
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.PARENT
-- ID: 10 PARENT_ID: 1
-- ID: 20 PARENT_ID: 2
-- ID: 30 PARENT_ID: NULL
-- msg: UPDATE 3
-- CHILD_ID: 100
-- CHILD_ID: 200
-- CHILD_ID: NULL

-- # Keys can be swapped, and the referencing rows follow them. A referencing
-- # column can be part of a PRIMARY KEY.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT PRIMARY KEY REFERENCES parent ON UPDATE CASCADE, name VARCHAR(10));
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (parent_id, name) VALUES (1, 'one'), (2, 'two');
UPDATE parent SET id = 3 - id;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- msg: UPDATE 2
-- PARENT_ID: 1 NAME: two
-- PARENT_ID: 2 NAME: one

-- # A table can reference itself, including a row that references itself.
CREATE TABLE emp (id INT PRIMARY KEY, manager_id INT REFERENCES emp ON UPDATE CASCADE);
INSERT INTO emp (id, manager_id) VALUES (1, 1), (2, 1), (3, 2);
UPDATE emp SET id = id * 10;
SELECT * FROM emp;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: UPDATE 3
-- ID: 10 MANAGER_ID: 10
-- ID: 20 MANAGER_ID: 10
-- ID: 30 MANAGER_ID: 20

-- # ON UPDATE SET NULL and SET DEFAULT are like ON DELETE, and a composite key
-- # only changes when any of its columns change. The new values must satisfy
-- # the constraints.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT DEFAULT 5, FOREIGN KEY (x, y) REFERENCES parent (a, b) ON UPDATE SET NULL);
CREATE TABLE child2 (x INT DEFAULT 0, y INT DEFAULT 0, FOREIGN KEY (x, y) REFERENCES parent (a, b) ON UPDATE SET DEFAULT ON DELETE CASCADE);
INSERT INTO parent (a, b) VALUES (0, 0), (1, 1), (1, 2);
INSERT INTO child (x, y) VALUES (1, 1), (1, 2);
INSERT INTO child2 (x, y) VALUES (1, 1), (1, 2);
UPDATE parent SET b = 3 WHERE b = 1;
SELECT * FROM child;
SELECT * FROM child2;
UPDATE parent SET a = 5 WHERE a = 0;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 2
-- msg: INSERT 2
-- msg: UPDATE 1
-- X: NULL Y: NULL
-- X: 1 Y: 2
-- X: 0 Y: 0
-- X: 1 Y: 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD2
-- A: 0 B: 0
-- A: 1 B: 3
-- A: 1 B: 2

-- # A new value must fit the referencing column, which can't be NULL if it's
-- # NOT NULL.
CREATE TABLE parent (id VARCHAR(10) UNIQUE);
CREATE TABLE child (parent_id VARCHAR(3) NOT NULL REFERENCES parent (id) ON UPDATE CASCADE);
INSERT INTO parent (id) VALUES ('abc');
INSERT INTO child (parent_id) VALUES ('abc');
UPDATE parent SET id = 'abcdef';
UPDATE parent SET id = NULL;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 22001: string data right truncation for CHARACTER VARYING(3)
-- error 23502: violates non-null constraint: column PARENT_ID
-- PARENT_ID: abc

-- # ON UPDATE NO ACTION is the same as no ON UPDATE, and a row that's changed
-- # by ON UPDATE CASCADE can't be referenced by it.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, parent_id INT REFERENCES parent ON UPDATE CASCADE);
CREATE TABLE other (child_id INT REFERENCES child ON UPDATE NO ACTION, child_parent_id INT REFERENCES child (id));
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (id, parent_id) VALUES (10, 1);
INSERT INTO other (child_id) VALUES (10);
UPDATE parent SET id = 2;
UPDATE child SET id = 11;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: UPDATE 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (CHILD_ID) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.OTHER
-- ID: 10 PARENT_ID: 2

-- # A row that's changed by ON DELETE SET NULL can have its own ON UPDATE
-- # actions.
CREATE TABLE a (id INT PRIMARY KEY);
CREATE TABLE b (a_id INT UNIQUE REFERENCES a ON DELETE SET NULL);
CREATE TABLE c (b_id INT REFERENCES b (a_id) ON UPDATE CASCADE);
INSERT INTO a (id) VALUES (1);
INSERT INTO b (a_id) VALUES (1);
INSERT INTO c (b_id) VALUES (1);
DELETE FROM a;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: DELETE 1
-- B_ID: NULL

-- # The ON UPDATE is kept with the definition of the table, in either order with
-- # the ON DELETE.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (a INT REFERENCES parent ON UPDATE CASCADE, b INT REFERENCES parent ON DELETE SET NULL ON UPDATE SET DEFAULT, c INT REFERENCES parent ON UPDATE NO ACTION ON DELETE CASCADE);
SELECT constraint_name, update_rule, delete_rule FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 UPDATE_RULE: CASCADE DELETE_RULE: NO ACTION
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 UPDATE_RULE: SET DEFAULT DELETE_RULE: SET NULL
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_3 UPDATE_RULE: NO ACTION DELETE_RULE: CASCADE

-- # A row can't be changed by an update action while another transaction is
-- # writing it.
/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent ON UPDATE CASCADE);
INSERT INTO parent (id) VALUES (1);
START TRANSACTION;
INSERT INTO child (parent_id) VALUES (1);
/* connection 2 */
UPDATE parent SET id = 2;
/* connection 1 */
COMMIT;
/* connection 2 */
UPDATE parent SET id = 2;
SELECT * FROM child;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: PARENT_ID: 2

-- # A site (a column of a row) can't be updated to two different values by the
-- # actions of one statement, which is a triggered data change violation. Here,
-- # X is updated to 10 by the first key, and then the second key matches it.
-- # Nothing is changed.
CREATE TABLE p (id INT UNIQUE, k INT UNIQUE);
CREATE TABLE c (x INT REFERENCES p (id) ON UPDATE CASCADE, FOREIGN KEY (x) REFERENCES p (k) ON UPDATE CASCADE);
INSERT INTO p (id, k) VALUES (1, 10), (2, 1);
INSERT INTO c (x) VALUES (1);
UPDATE p SET id = 10, k = 30 WHERE id = 1;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- error 27000: triggered data change violation: column X of a row of PUBLIC.C is updated to two different values
-- X: 1

-- # NULL is a different value too.
CREATE TABLE p (id INT UNIQUE, k INT UNIQUE);
CREATE TABLE c (x INT REFERENCES p (id) ON UPDATE CASCADE, FOREIGN KEY (x) REFERENCES p (k) ON UPDATE SET NULL);
INSERT INTO p (id, k) VALUES (1, 10), (2, 1);
INSERT INTO c (x) VALUES (1);
UPDATE p SET id = 10, k = 30 WHERE id = 1;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- error 27000: triggered data change violation: column X of a row of PUBLIC.C is updated to two different values
-- X: 1

-- # A cycle of ON UPDATE CASCADE keys ends, since each site can only be updated
-- # once.
CREATE TABLE t (a INT UNIQUE, b INT UNIQUE, FOREIGN KEY (b) REFERENCES t (a) ON UPDATE CASCADE, FOREIGN KEY (a) REFERENCES t (b) ON UPDATE CASCADE);
INSERT INTO t (a, b) VALUES (1, 2), (2, 1);
UPDATE t SET a = 3 WHERE a = 1;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: UPDATE 1
-- A: 3 B: 2
-- A: 2 B: 3
