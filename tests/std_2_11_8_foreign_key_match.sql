-- # MATCH FULL needs every column of the FOREIGN KEY to be NULL, or none of
-- # them (Syntax Rules, 18.b.iii). A row where every column is NULL doesn't
-- # reference a row.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH FULL);
INSERT INTO parent (a, b) VALUES (1, 1);
INSERT INTO child (x, y) VALUES (1, 1), (NULL, NULL);
INSERT INTO child (x, y) VALUES (1, NULL);
INSERT INTO child (x, y) VALUES (NULL, 2);
INSERT INTO child (x, y) VALUES (2, 2);
UPDATE child SET y = NULL;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- X: 1 Y: 1
-- X: NULL Y: NULL

-- # MATCH SIMPLE is the same as no MATCH (Syntax Rules, 1), so a row with a
-- # NULL in any column doesn't reference a row (Syntax Rules, 18.b.i). The
-- # MATCH is kept with the definition of the table, and is the MATCH_OPTION of
-- # REFERENTIAL_CONSTRAINTS (NONE for SIMPLE), even after the table is altered.
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (a INT REFERENCES parent MATCH SIMPLE, b INT REFERENCES parent MATCH FULL ON DELETE CASCADE, c INT REFERENCES parent MATCH PARTIAL ON UPDATE SET NULL ON DELETE SET NULL);
INSERT INTO child (a, b, c) VALUES (NULL, NULL, NULL);
ALTER TABLE child ADD COLUMN d INT;
SELECT constraint_name, match_option, update_rule, delete_rule FROM information_schema.referential_constraints;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_1 MATCH_OPTION: NONE UPDATE_RULE: NO ACTION DELETE_RULE: NO ACTION
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_2 MATCH_OPTION: FULL UPDATE_RULE: NO ACTION DELETE_RULE: CASCADE
-- CONSTRAINT_NAME: CHILD_FOREIGN_KEY_3 MATCH_OPTION: PARTIAL UPDATE_RULE: SET NULL DELETE_RULE: SET NULL

-- # ON UPDATE SET NULL with MATCH FULL sets every column to NULL (General
-- # Rules, 10.a.ii.2.A), but SET DEFAULT only sets the columns that correspond
-- # to the updated referenced columns (General Rules, 10.a.iii.1). Setting a
-- # referenced column to the same value isn't an update.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH FULL ON UPDATE SET NULL);
CREATE TABLE child2 (x INT, y INT DEFAULT 0, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH FULL ON UPDATE SET DEFAULT);
INSERT INTO parent (a, b) VALUES (1, 0), (1, 1), (2, 2);
INSERT INTO child (x, y) VALUES (1, 1);
INSERT INTO child2 (x, y) VALUES (1, 1), (2, 2);
UPDATE parent SET a = a;
UPDATE parent SET b = 5 WHERE b = 1;
SELECT * FROM child;
SELECT * FROM child2;
UPDATE parent SET b = 6 WHERE a = 2;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 1
-- msg: INSERT 2
-- msg: UPDATE 3
-- msg: UPDATE 1
-- X: NULL Y: NULL
-- X: 1 Y: 0
-- X: 2 Y: 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD2
-- A: 1 B: 0
-- A: 1 B: 5
-- A: 2 B: 2

-- # With MATCH PARTIAL, a row with any column that isn't NULL must reference a
-- # row that has the same values in those columns (Syntax Rules, 18.b.ii). The
-- # referenced row can have a NULL in another column.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL);
INSERT INTO parent (a, b) VALUES (1, 1), (2, NULL);
INSERT INTO child (x, y) VALUES (1, NULL), (NULL, 1), (NULL, NULL), (1, 1), (2, NULL);
INSERT INTO child (x, y) VALUES (NULL, 2);
INSERT INTO child (x, y) VALUES (2, 2);
INSERT INTO child (x, y) VALUES (3, NULL);
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 5
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- X: 1 Y: NULL
-- X: NULL Y: 1
-- X: NULL Y: NULL
-- X: 1 Y: 1
-- X: 2 Y: NULL

-- # A referenced row can be deleted or updated as long as each row that
-- # referenced it still references another row.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL);
INSERT INTO parent (a, b) VALUES (1, 1), (1, 2), (3, 3);
INSERT INTO child (x, y) VALUES (1, NULL), (NULL, 3);
DELETE FROM parent WHERE b = 1;
DELETE FROM parent WHERE b = 2;
UPDATE parent SET b = 4 WHERE b = 3;
UPDATE parent SET a = 4 WHERE b = 3;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 2
-- msg: DELETE 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- msg: UPDATE 1
-- A: 1 B: 2
-- A: 4 B: 3

-- # With MATCH PARTIAL, ON DELETE only changes the unique matching rows, which
-- # don't reference any other row (General Rules, 6.b and 9.b). SET NULL sets
-- # every column to NULL.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL ON DELETE CASCADE);
CREATE TABLE child2 (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL ON DELETE SET NULL);
INSERT INTO parent (a, b) VALUES (1, 1), (1, 2), (2, 1);
INSERT INTO child (x, y) VALUES (1, NULL), (NULL, 2), (1, 1);
INSERT INTO child2 (x, y) VALUES (1, NULL), (NULL, 2), (1, 1);
DELETE FROM parent WHERE b = 2;
SELECT * FROM child;
SELECT * FROM child2;
DELETE FROM parent WHERE a = 1;
SELECT * FROM child;
SELECT * FROM child2;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 3
-- msg: INSERT 3
-- msg: DELETE 1
-- X: 1 Y: NULL
-- X: 1 Y: 1
-- X: 1 Y: NULL
-- X: NULL Y: NULL
-- X: 1 Y: 1
-- msg: DELETE 1
-- X: NULL Y: NULL
-- X: NULL Y: NULL
-- X: NULL Y: NULL

-- # With MATCH PARTIAL, ON UPDATE only changes the columns of the unique
-- # matching rows that aren't NULL, and correspond to an updated referenced
-- # column (General Rules, 10.b).
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL ON UPDATE CASCADE);
CREATE TABLE child2 (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL ON UPDATE SET NULL);
INSERT INTO parent (a, b) VALUES (1, 1), (2, 2);
INSERT INTO child (x, y) VALUES (1, 1), (NULL, 1), (1, NULL);
INSERT INTO child2 (x, y) VALUES (2, 2), (NULL, 2), (2, NULL);
UPDATE parent SET b = 5 WHERE a = 1;
UPDATE parent SET a = 6 WHERE a = 2;
SELECT * FROM child;
SELECT * FROM child2;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 3
-- msg: INSERT 3
-- msg: UPDATE 1
-- msg: UPDATE 1
-- X: 1 Y: 5
-- X: NULL Y: 5
-- X: 1 Y: NULL
-- X: NULL Y: 2
-- X: NULL Y: 2
-- X: NULL Y: NULL

-- # A row that was deleted by one action can't be changed by another, with
-- # MATCH PARTIAL too.
CREATE TABLE parent (a INT UNIQUE, b INT, UNIQUE (a, b));
CREATE TABLE child (id INT REFERENCES parent (a) ON DELETE CASCADE, x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL ON DELETE SET NULL);
INSERT INTO parent (a, b) VALUES (1, 1);
INSERT INTO child (id, x, y) VALUES (1, 1, NULL);
DELETE FROM parent;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 27000: triggered data change violation: a row of ":memory:".PUBLIC.CHILD that was deleted is updated
-- ID: 1 X: 1 Y: NULL

-- # A deferred FOREIGN KEY with MATCH PARTIAL is checked when the transaction
-- # is committed.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL DEFERRABLE INITIALLY DEFERRED);
INSERT INTO parent (a, b) VALUES (1, 1);
INSERT INTO child (x, y) VALUES (1, NULL);
START TRANSACTION;
DELETE FROM parent;
INSERT INTO parent (a, b) VALUES (1, 2);
COMMIT;
START TRANSACTION;
DELETE FROM parent;
COMMIT;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: DELETE 1
-- msg: INSERT 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: DELETE 1
-- error 40002: integrity constraint violation: violates foreign key constraint: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- A: 1 B: 2

-- # RESTRICT works with MATCH SIMPLE and FULL like it does without a MATCH: it's
-- # an error when a matching row references the deleted or updated row (General
-- # Rules, 9.a.iv and 10.a.iv). With MATCH SIMPLE a row with a NULL doesn't
-- # reference a row.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH FULL ON UPDATE RESTRICT ON DELETE RESTRICT);
CREATE TABLE child2 (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH SIMPLE ON DELETE RESTRICT);
INSERT INTO parent (a, b) VALUES (1, 1), (2, 2);
INSERT INTO child (x, y) VALUES (1, 1), (NULL, NULL);
INSERT INTO child2 (x, y) VALUES (2, NULL);
DELETE FROM parent WHERE a = 1;
UPDATE parent SET b = 5 WHERE a = 1;
DELETE FROM parent WHERE a = 2;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- msg: INSERT 1
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- msg: DELETE 1
-- A: 1 B: 1

-- # With MATCH PARTIAL, ON DELETE RESTRICT is only an error for a unique
-- # matching row (General Rules, 9.b.iv). A row that also matches another row
-- # that isn't deleted isn't one.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL ON DELETE RESTRICT);
INSERT INTO parent (a, b) VALUES (1, 1), (1, 2), (2, 2);
INSERT INTO child (x, y) VALUES (1, NULL), (2, NULL), (NULL, NULL);
DELETE FROM parent WHERE a = 1 AND b = 1;
DELETE FROM parent WHERE a = 1 AND b = 2;
DELETE FROM parent WHERE a = 2;
DELETE FROM parent WHERE a = 1;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 3
-- msg: DELETE 1
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- A: 1 B: 2
-- A: 2 B: 2

-- # With MATCH PARTIAL, ON UPDATE RESTRICT is an error for a unique matching
-- # row when a referenced column changes (General Rules, 10.b.iv), even when
-- # the column is NULL in the row, because it's still the row it matches.
CREATE TABLE parent (a INT, b INT, UNIQUE (a, b));
CREATE TABLE child (x INT, y INT, FOREIGN KEY (x, y) REFERENCES parent (a, b) MATCH PARTIAL ON UPDATE RESTRICT);
INSERT INTO parent (a, b) VALUES (1, 1), (2, 2), (3, 3);
INSERT INTO child (x, y) VALUES (NULL, 1), (2, NULL);
UPDATE parent SET b = 5 WHERE a = 1;
UPDATE parent SET a = 5 WHERE a = 1;
UPDATE parent SET a = 6 WHERE a = 2;
UPDATE parent SET a = 2 WHERE a = 2;
UPDATE parent SET a = 7 WHERE a = 3;
SELECT * FROM parent;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 3
-- msg: INSERT 2
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- error 23001: restrict violation: FOREIGN KEY (X, Y) REFERENCES ":memory:".PUBLIC.PARENT (A, B) on ":memory:".PUBLIC.CHILD
-- msg: UPDATE 1
-- msg: UPDATE 1
-- A: 1 B: 1
-- A: 2 B: 2
-- A: 7 B: 3

-- # MATCH needs F741.
/* flags */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent MATCH FULL);
-- flags:
-- msg: CREATE TABLE 1
-- flags: F741
-- msg: CREATE TABLE 1
