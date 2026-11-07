-- # A UNIQUE constraint has its own UNIQUE index, with the same name as the
-- # constraint. It can be used to find rows, like any other index.
/* extensions V001-01 */
CREATE TABLE t (id INT PRIMARY KEY, u INT UNIQUE);
INSERT INTO t (id, u) VALUES (1, 10), (2, 20);
EXPLAIN SELECT * FROM t WHERE u = 20;
SELECT * FROM t WHERE u = 20;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- EXPLAIN: INDEX ":memory:".PUBLIC.T_UNIQUE_1 ON ":memory:".PUBLIC.T (ID INTEGER NOT NULL, U INTEGER) RANGE U = 20
-- EXPLAIN: WHERE U = 20
-- EXPLAIN: EXPR (":memory:".PUBLIC.T.ID INTEGER NOT NULL, ":memory:".PUBLIC.T.U INTEGER)
-- ID: 2 U: 20

-- # The index of a UNIQUE constraint can't be dropped, it's dropped with the
-- # constraint.
/* extensions V003-01 V105-02 */
CREATE TABLE t (id INT PRIMARY KEY, u INT CONSTRAINT t_u UNIQUE);
DROP INDEX t_u;
ALTER TABLE t DROP CONSTRAINT t_u;
DROP INDEX t_u;
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on constraint T_U on ":memory:".PUBLIC.T
-- msg: ALTER TABLE 1
-- error 42704: no such index: ":memory:".PUBLIC.T_U

-- # A UNIQUE constraint that's added gets an index, unless the rows already
-- # have the same values.
/* extensions V003-01 */
CREATE TABLE t (id INT PRIMARY KEY, u INT);
INSERT INTO t (id, u) VALUES (1, 10), (2, 10);
ALTER TABLE t ADD CONSTRAINT t_u UNIQUE (u);
DROP INDEX t_u;
UPDATE t SET u = 20 WHERE id = 2;
ALTER TABLE t ADD CONSTRAINT t_u UNIQUE (u);
DROP INDEX t_u;
INSERT INTO t (id, u) VALUES (3, 20);
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- error 42704: no such index: ":memory:".PUBLIC.T_U
-- msg: UPDATE 1
-- msg: ALTER TABLE 1
-- error 2BP01: dependent objects still exist on constraint T_U on ":memory:".PUBLIC.T
-- error 23505: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T

-- # A constraint can't have the name of an index, because its index needs the
-- # name. A constraint without a name gets one that isn't the name of an index.
/* extensions V002-01 V003-01 */
CREATE TABLE t (id INT PRIMARY KEY, u INT);
CREATE INDEX t_unique_1 ON t (id);
ALTER TABLE t ADD CONSTRAINT t_unique_1 UNIQUE (u);
ALTER TABLE t ADD UNIQUE (u);
DROP INDEX t_unique_2;
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- error 42P07: duplicate index: ":memory:".PUBLIC.T_UNIQUE_1
-- msg: ALTER TABLE 1
-- error 2BP01: dependent objects still exist on constraint T_UNIQUE_2 on ":memory:".PUBLIC.T

-- # A DEFERRABLE UNIQUE constraint can have the same values until it's checked.
CREATE TABLE t (id INT PRIMARY KEY, u INT UNIQUE DEFERRABLE INITIALLY DEFERRED);
INSERT INTO t (id, u) VALUES (1, 10), (2, 20);
START TRANSACTION;
UPDATE t SET u = 10 WHERE id = 2;
UPDATE t SET u = 20 WHERE id = 1;
COMMIT;
START TRANSACTION;
UPDATE t SET u = 10 WHERE id = 1;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- msg: UPDATE 1
-- msg: COMMIT
-- msg: START TRANSACTION
-- msg: UPDATE 1
-- error 40002: integrity constraint violation: violates unique constraint: UNIQUE (U) on ":memory:".PUBLIC.T
-- ID: 1 U: 20
-- ID: 2 U: 10

-- # Dropping a column drops a UNIQUE constraint (and its index) that only has
-- # that column.
/* extensions V003-01 V105-01 */
CREATE TABLE t (id INT PRIMARY KEY, u INT CONSTRAINT t_u UNIQUE);
ALTER TABLE t DROP COLUMN u;
DROP INDEX t_u;
-- msg: CREATE TABLE 1
-- msg: ALTER TABLE 1
-- error 42704: no such index: ":memory:".PUBLIC.T_U

-- # A FOREIGN KEY uses an index whose first columns are its columns, to find
-- # the rows that reference a row. It gets one with its name if there isn't
-- # one, which is kept when the FOREIGN KEY is dropped.
/* extensions V001-01 V003-01 V105-02 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT PRIMARY KEY, p INT CONSTRAINT child_p REFERENCES parent);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (id, p) VALUES (1, 1), (2, 1);
EXPLAIN SELECT * FROM child WHERE p = 1;
DROP INDEX child_p;
DELETE FROM parent WHERE id = 1;
DELETE FROM parent WHERE id = 2;
ALTER TABLE child DROP CONSTRAINT child_p;
DROP INDEX child_p;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- EXPLAIN: INDEX ":memory:".PUBLIC.CHILD_P ON ":memory:".PUBLIC.CHILD (ID INTEGER NOT NULL, P INTEGER) RANGE P = 1
-- EXPLAIN: WHERE P = 1
-- EXPLAIN: EXPR (":memory:".PUBLIC.CHILD.ID INTEGER NOT NULL, ":memory:".PUBLIC.CHILD.P INTEGER)
-- error 2BP01: dependent objects still exist on constraint CHILD_P on ":memory:".PUBLIC.CHILD
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: DELETE 1
-- msg: ALTER TABLE 1
-- msg: DROP INDEX 1

-- # An index that's already there is used, and it can be dropped when another
-- # index can be used instead.
/* extensions V002-01 V003-01 */
CREATE TABLE parent (a INT, b INT, PRIMARY KEY (a, b));
CREATE TABLE child (x INT, a INT, b INT);
CREATE INDEX child_x ON child (x);
CREATE INDEX child_ba ON child (b DESC, a, x);
ALTER TABLE child ADD CONSTRAINT child_fk FOREIGN KEY (a, b) REFERENCES parent;
DROP INDEX child_fk;
CREATE INDEX child_ab ON child (a, b);
DROP INDEX child_x;
DROP INDEX child_ab;
DROP INDEX child_ba;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
-- error 42704: no such index: ":memory:".PUBLIC.CHILD_FK
-- msg: CREATE INDEX 1
-- msg: DROP INDEX 1
-- msg: DROP INDEX 1
-- error 2BP01: dependent objects still exist on constraint CHILD_FK on ":memory:".PUBLIC.CHILD

-- # The rows that reference a row are found with the index, including with a
-- # DESC column and the other columns of the key in another order.
/* extensions V002-01 */
CREATE TABLE parent (a INT, b INT, PRIMARY KEY (a, b));
CREATE TABLE child (id INT PRIMARY KEY, a INT, b INT);
CREATE INDEX child_ba ON child (b DESC, a);
ALTER TABLE child ADD FOREIGN KEY (a, b) REFERENCES parent ON DELETE CASCADE ON UPDATE CASCADE;
INSERT INTO parent (a, b) VALUES (1, 1), (1, 2), (2, 1);
INSERT INTO child (id, a, b) VALUES (1, 1, 1), (2, 1, 2), (3, 2, 1), (4, 1, 2), (5, NULL, 2);
UPDATE parent SET b = 3 WHERE a = 1 AND b = 2;
DELETE FROM parent WHERE a = 1 AND b = 1;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE INDEX 1
-- msg: ALTER TABLE 1
-- msg: INSERT 3
-- msg: INSERT 5
-- msg: UPDATE 1
-- msg: DELETE 1
-- ID: 2 A: 1 B: 3
-- ID: 3 A: 2 B: 1
-- ID: 4 A: 1 B: 3
-- ID: 5 A: NULL B: 2

-- # A FOREIGN KEY can reference a UNIQUE constraint, with its columns in
-- # another order.
CREATE TABLE parent (a INT, b VARCHAR(10), UNIQUE (b, a));
CREATE TABLE child (a INT, b VARCHAR(10), FOREIGN KEY (b, a) REFERENCES parent (b, a) ON DELETE SET NULL);
INSERT INTO parent (a, b) VALUES (1, 'x'), (2, 'x');
INSERT INTO child (a, b) VALUES (1, 'x'), (2, 'x');
INSERT INTO child (a, b) VALUES (3, 'x');
DELETE FROM parent WHERE a = 1;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (B, A) REFERENCES ":memory:".PUBLIC.PARENT (B, A) on ":memory:".PUBLIC.CHILD
-- msg: DELETE 1
-- A: NULL B: NULL
-- A: 2 B: x

-- # A value that the other column can't hold exactly can't be referenced.
CREATE TABLE parent (id BIGINT PRIMARY KEY);
CREATE TABLE child (p INT REFERENCES parent ON DELETE CASCADE);
INSERT INTO parent (id) VALUES (1), (10000000000);
INSERT INTO child (p) VALUES (1);
DELETE FROM parent WHERE id = 10000000000;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 1
-- msg: DELETE 1

CREATE TABLE parent (id INT PRIMARY KEY, d DOUBLE PRECISION UNIQUE);
CREATE TABLE child (p BIGINT REFERENCES parent, q INT REFERENCES parent (d));
CREATE TABLE child2 (p NUMERIC(20, 1) REFERENCES parent);
INSERT INTO parent (id, d) VALUES (1, 2.0);
INSERT INTO child (p, q) VALUES (1, 2);
INSERT INTO child (p) VALUES (10000000000);
INSERT INTO child2 (p) VALUES (1.0);
INSERT INTO child2 (p) VALUES (1.5);
DELETE FROM parent WHERE id = 1;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: INSERT 1
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD2
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD

CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (p DOUBLE PRECISION REFERENCES parent ON DELETE CASCADE);
INSERT INTO parent (id) VALUES (1), (2);
INSERT INTO child (p) VALUES (1.0), (2.0);
INSERT INTO child (p) VALUES (1.5);
DELETE FROM parent WHERE id = 1;
SELECT * FROM child;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: INSERT 2
-- error 23503: violates foreign key constraint: FOREIGN KEY (P) REFERENCES ":memory:".PUBLIC.PARENT (ID) on ":memory:".PUBLIC.CHILD
-- msg: DELETE 1
-- P: 2e0
