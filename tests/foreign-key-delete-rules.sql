-- # ON DELETE CASCADE deletes the rows that reference a deleted row, and the
-- # rows that reference those rows, and so on.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, parent_id INT REFERENCES parent ON DELETE CASCADE);
CREATE TABLE grandchild (child_id INT, FOREIGN KEY (child_id) REFERENCES child (id) ON DELETE CASCADE);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (id, parent_id) VALUES (10, 1), (11, 1), (20, 2), (30, NULL);
INSERT INTO grandchild (child_id) VALUES (10), (11), (20), (NULL);
DELETE FROM parent WHERE id = 1;
SELECT * FROM child;
SELECT * FROM grandchild;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 4
-- msg: INSERT 4
-- msg: DELETE 1
-- ID: 20 PARENT_ID: 2
-- ID: 30 PARENT_ID: NULL
-- CHILD_ID: 20
-- CHILD_ID: NULL

-- # A table can reference itself, so deleting the root of a tree deletes the
-- # whole tree.
CREATE TABLE emp (id INT PRIMARY KEY, manager_id INT REFERENCES emp ON DELETE CASCADE);
INSERT INTO emp (id, manager_id) VALUES (1, NULL), (2, 1), (3, 2), (4, 3), (5, NULL), (6, 5);
DELETE FROM emp WHERE id = 2;
SELECT * FROM emp;
DELETE FROM emp;
SELECT * FROM emp;
-- msg: CREATE TABLE 1
-- msg: INSERT 6
-- msg: DELETE 1
-- ID: 1 MANAGER_ID: NULL
-- ID: 5 MANAGER_ID: NULL
-- ID: 6 MANAGER_ID: 5
-- msg: DELETE 3

-- # ON DELETE SET NULL sets every referencing column to NULL. A row with a NULL
-- # in any of the referenced columns can't be referenced.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) ON DELETE SET NULL);
INSERT INTO parent (a, b) VALUES (1, 1), (1, 2), (NULL, 2);
INSERT INTO child (x, y) VALUES (1, 1), (1, 2), (1, NULL);
DELETE FROM parent WHERE b = 1;
DELETE FROM parent WHERE a IS NULL;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 3
-- msg: DELETE 1
-- msg: DELETE 1
-- X: NULL Y: NULL
-- X: 1 Y: 2
-- X: 1 Y: NULL

-- # It's an error if a referencing column can't be NULL.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT NOT NULL REFERENCES parent ON DELETE SET NULL);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (parent_id) VALUES (1);
DELETE FROM parent;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23502: violates non-null constraint: column PARENT_ID
-- ID: 1

-- # ON DELETE SET DEFAULT sets every referencing column to its default, which
-- # must still reference a row. It's NULL when there's no default.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT, parent_id INT DEFAULT 0 REFERENCES parent ON DELETE SET DEFAULT, other_id INT REFERENCES parent ON DELETE SET DEFAULT);
INSERT INTO parent (id) VALUES (0), (1), (2);
INSERT INTO child (id, parent_id, other_id) VALUES (1, 1, 2), (2, 2, 1);
DELETE FROM parent WHERE id = 1;
SELECT * FROM child;
DELETE FROM parent WHERE id = 0;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 2
-- msg: DELETE 1
-- ID: 1 PARENT_ID: 0 OTHER_ID: 2
-- ID: 2 PARENT_ID: 2 OTHER_ID: NULL
-- error 23503: violates foreign key constraint: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- ID: 1 PARENT_ID: 0 OTHER_ID: 2
-- ID: 2 PARENT_ID: 2 OTHER_ID: NULL

-- # A row that's changed by SET DEFAULT must satisfy the other constraints of
-- # its table, and it can get a new PRIMARY KEY.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT DEFAULT 0 PRIMARY KEY REFERENCES parent ON DELETE SET DEFAULT, CHECK (parent_id < 5));
CREATE TABLE child2 (parent_id INT DEFAULT 9 REFERENCES parent ON DELETE SET DEFAULT, CHECK (parent_id < 5));
CREATE TABLE child3 (parent_id INT DEFAULT 0 UNIQUE REFERENCES parent ON DELETE SET DEFAULT);
INSERT INTO parent (id) VALUES (0), (1), (2), (3);
INSERT INTO child (parent_id) VALUES (1);
INSERT INTO child2 (parent_id) VALUES (2);
INSERT INTO child3 (parent_id) VALUES (0), (3);
DELETE FROM parent WHERE id = 1;
SELECT * FROM child;
DELETE FROM parent WHERE id = 2;
DELETE FROM parent WHERE id = 3;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 4
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 2
-- msg: DELETE 1
-- PARENT_ID: 0
-- error 23514: violates check constraint: CHECK (PARENT_ID < 5) on ":memory:".PUBLIC.CHILD2
-- error 23505: violates unique constraint: UNIQUE (PARENT_ID) on ":memory:".PUBLIC.CHILD3
-- ID: 0
-- ID: 2
-- ID: 3

-- # ON DELETE NO ACTION is the same as no ON DELETE. A row that's deleted by
-- # CASCADE can't be referenced by a FOREIGN KEY without a delete action, and a
-- # DELETE can't delete a row that's still referenced after the actions.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, parent_id INT REFERENCES parent ON DELETE CASCADE);
CREATE TABLE other (child_id INT REFERENCES child ON DELETE NO ACTION);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (id, parent_id) VALUES (10, 1), (20, 2);
INSERT INTO other (child_id) VALUES (10);
DELETE FROM parent WHERE id = 1;
DELETE FROM parent WHERE id = 2;
SELECT * FROM child;
DELETE FROM child WHERE id = 10;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (CHILD_ID) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.OTHER
-- msg: DELETE 1
-- ID: 10 PARENT_ID: 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (CHILD_ID) REFERENCES ":memory:".PUBLIC.CHILD (ID) on ":memory:".PUBLIC.OTHER

-- # The ON DELETE is kept with the definition of the table, including one that's
-- # added by ALTER TABLE.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (a INT REFERENCES parent ON DELETE CASCADE, b INT REFERENCES parent ON DELETE NO ACTION, c INT);
ALTER TABLE child ADD CONSTRAINT c_fk FOREIGN KEY (c) REFERENCES parent ON DELETE SET NULL;
ALTER TABLE child ADD COLUMN d INT DEFAULT 1 REFERENCES parent ON DELETE SET DEFAULT;
SELECT constraint_name, delete_rule FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 DELETE_RULE: CASCADE
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 DELETE_RULE: NO ACTION
-- CONSTRAINT_NAME: C_FK DELETE_RULE: SET NULL
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_3 DELETE_RULE: SET DEFAULT

CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT REFERENCES parent ON DELETE CASCADE ON DELETE CASCADE);
CREATE TABLE child (id INT REFERENCES parent ON DELETE RESTRICT);
CREATE TABLE child (id INT REFERENCES parent ON UPDATE RESTRICT);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unexpected DELETE, expecting UPDATE
-- error 42601: syntax error: unexpected RESTRICT, expecting CASCADE or NO or SET
-- error 42601: syntax error: unexpected RESTRICT, expecting CASCADE or NO or SET

-- # A row can't be changed by a delete action while another transaction is
-- # writing it. Once that transaction has finished, its rows are changed too.
/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent ON DELETE CASCADE);
INSERT INTO parent (id) VALUES (1);
START TRANSACTION;
INSERT INTO child (parent_id) VALUES (1);
/* connection 2 */
DELETE FROM parent;
/* connection 1 */
COMMIT;
/* connection 2 */
DELETE FROM parent;
SELECT * FROM child;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT
-- 2: msg: DELETE 1
