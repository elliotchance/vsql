-- # ON DELETE RESTRICT is an error (23001) when a deleted row is referenced
-- # (General Rules, 9.a.iv). A row that isn't referenced can be deleted.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent ON DELETE RESTRICT);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (parent_id) VALUES (1), (NULL);
DELETE FROM parent WHERE id = 1;
DELETE FROM parent WHERE id = 2;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- error 23001: restrict violation: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: DELETE 1
-- ID: 1

-- # ON UPDATE RESTRICT is an error when a referenced key changes (General
-- # Rules, 10.a.iv), but not when it's set to the same value, or when another
-- # column changes.
CREATE TABLE parent (id INT PRIMARY KEY, x INT);
CREATE TABLE child (parent_id INT REFERENCES parent ON UPDATE RESTRICT);
INSERT INTO parent (id, x) VALUES (1, 10), (2, 20);
INSERT INTO child (parent_id) VALUES (1);
UPDATE parent SET id = 3 WHERE id = 1;
UPDATE parent SET id = 1, x = 11 WHERE id = 1;
UPDATE parent SET id = 4 WHERE id = 2;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- error 23001: restrict violation: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: UPDATE 1
-- msg: UPDATE 1
-- ID: 1 X: 11
-- ID: 4 X: 20

-- # Unlike NO ACTION, the matching rows are the rows from before the statement,
-- # so it's still an error when the same statement deletes the referencing rows
-- # too.
CREATE TABLE emp (id INT PRIMARY KEY, manager_id INT REFERENCES emp ON DELETE RESTRICT);
INSERT INTO emp (id, manager_id) VALUES (1, NULL), (2, 1), (3, NULL);
DELETE FROM emp WHERE id IN (1, 2);
DELETE FROM emp WHERE id IN (2, 3);
SELECT * FROM emp;
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- error 23001: restrict violation: FOREIGN KEY (MANAGER_ID) REFERENCES ":memory:".PUBLIC.EMP (ID) on ":memory:".PUBLIC.EMP
-- msg: DELETE 2
-- ID: 1 MANAGER_ID: NULL

-- # The same is true for a row that's deleted by another referential action of
-- # the same statement, before the RESTRICT is checked.
CREATE TABLE a (id INT PRIMARY KEY);
CREATE TABLE b (id INT PRIMARY KEY, a_id INT REFERENCES a ON DELETE CASCADE);
CREATE TABLE c (b_id INT REFERENCES b ON DELETE RESTRICT, a_id INT REFERENCES a ON DELETE CASCADE);
INSERT INTO a (id) VALUES (1);
INSERT INTO b (id, a_id) VALUES (10, 1);
INSERT INTO c (b_id, a_id) VALUES (10, 1);
DELETE FROM a;
SELECT * FROM c;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23001: restrict violation: FOREIGN KEY (B_ID) REFERENCES ":memory:".PUBLIC.B (ID) on ":memory:".PUBLIC.C
-- B_ID: 10 A_ID: 1

-- # A referential action can be stopped by a RESTRICT on a table further away,
-- # which undoes the whole statement.
CREATE TABLE a (id INT PRIMARY KEY);
CREATE TABLE b (id INT PRIMARY KEY, a_id INT REFERENCES a ON DELETE CASCADE);
CREATE TABLE c (b_id INT REFERENCES b ON DELETE RESTRICT);
INSERT INTO a (id) VALUES (1), (2);
INSERT INTO b (id, a_id) VALUES (10, 1), (20, 2);
INSERT INTO c (b_id) VALUES (10);
DELETE FROM a;
DELETE FROM a WHERE id = 2;
SELECT * FROM a;
SELECT * FROM b;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- msg: INSERT 1
-- error 23001: restrict violation: FOREIGN KEY (B_ID) REFERENCES ":memory:".PUBLIC.B (ID) on ":memory:".PUBLIC.C
-- msg: DELETE 1
-- ID: 1
-- ID: 10 A_ID: 1

-- # RESTRICT is checked straight away, even when the FOREIGN KEY is deferred.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (parent_id) VALUES (1);
START TRANSACTION;
DELETE FROM parent;
COMMIT;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- error 23001: restrict violation: FOREIGN KEY (PARENT_ID) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: COMMIT
-- ID: 1

-- # The rules are kept with the definition of the table, and are in
-- # REFERENTIAL_CONSTRAINTS.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (a INT REFERENCES parent ON DELETE RESTRICT, b INT REFERENCES parent ON UPDATE RESTRICT ON DELETE CASCADE);
SELECT constraint_name, update_rule, delete_rule FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 UPDATE_RULE: NO ACTION DELETE_RULE: RESTRICT
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 UPDATE_RULE: RESTRICT DELETE_RULE: CASCADE

-- # A generated column can use RESTRICT, since it doesn't change the column.
CREATE TABLE p (id INT PRIMARY KEY);
CREATE TABLE c (x INT, y INT GENERATED ALWAYS AS (x) REFERENCES p ON UPDATE RESTRICT ON DELETE RESTRICT);
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1

-- # RESTRICT needs T191.
/* flags */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent ON DELETE RESTRICT);
-- flags:
-- msg: CREATE TABLE 1
-- flags: F191, T191
-- msg: CREATE TABLE 1
