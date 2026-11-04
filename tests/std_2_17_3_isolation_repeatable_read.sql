-- # A REPEATABLE READ transaction sees a snapshot of the rows that were
-- # committed when it started (snapshot isolation), so a row it has read can't
-- # change (P2, a non-repeatable read, 4.41.4), and other connections can still
-- # commit while it's active. READ COMMITTED sees the change, and SERIALIZABLE
-- # doesn't let the other connection commit until it ends.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
SELECT * FROM t;
/* connection 1 */
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: msg: UPDATE 1
-- 2: X: 2
-- 1: X: 1
-- 1: msg: COMMIT
-- 1: X: 2

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
SELECT * FROM t;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: msg: UPDATE 1
-- 1: X: 2
-- 1: msg: COMMIT

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
SELECT * FROM t;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: X: 1
-- 1: msg: COMMIT

-- # Rows that another connection inserts or deletes (and commits) after it
-- # started aren't seen either. The snapshot is taken by START TRANSACTION, so
-- # changes committed before then are seen.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
/* connection 2 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 1 */
INSERT INTO t (x) VALUES (3);
DELETE FROM t WHERE x = 1;
SELECT * FROM t;
/* connection 2 */
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 2: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: DELETE 1
-- 1: X: 2
-- 1: X: 3
-- 2: X: 1
-- 2: X: 2
-- 2: msg: COMMIT
-- 2: X: 2
-- 2: X: 3

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
/* connection 2 */
INSERT INTO t (x) VALUES (3);
DELETE FROM t WHERE x = 1;
/* connection 1 */
SELECT * FROM t;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 1: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 2: msg: DELETE 1
-- 1: X: 2
-- 1: X: 3
-- 1: msg: COMMIT

-- # It sees its own changes, but not the changes of a transaction that hasn't
-- # committed, even once that transaction commits.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
INSERT INTO t (x) VALUES (2);
/* connection 2 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO t (x) VALUES (3);
SELECT * FROM t;
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM t;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 2: X: 1
-- 2: X: 3
-- 1: msg: COMMIT
-- 2: X: 1
-- 2: X: 3
-- 2: msg: COMMIT
-- 2: X: 1
-- 2: X: 2
-- 2: X: 3

-- # First committer wins: a row that another transaction changed and committed
-- # after the snapshot can't be updated or deleted (4.41.5). The transaction is
-- # rolled back, so that it can be tried again.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
UPDATE t SET x = x + 10;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: msg: UPDATE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT
-- 1: X: 2

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
DELETE FROM t;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: X: 2

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
DELETE FROM t;
/* connection 1 */
SELECT * FROM t;
UPDATE t SET x = 2;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: DELETE 1
-- 1: X: 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row

-- # READ COMMITTED updates the latest version instead (a lost update isn't
-- # possible either way).
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
UPDATE t SET x = x + 10;
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: msg: UPDATE 1
-- 1: msg: UPDATE 1
-- 1: msg: COMMIT
-- 1: X: 12

-- # A row that's changed by a transaction that's still active is the same as
-- # READ COMMITTED: whichever changes it second fails.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
UPDATE t SET x = 2;
/* connection 2 */
UPDATE t SET x = 3;
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT
-- 2: X: 2

/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL READ COMMITTED;
UPDATE t SET x = 2;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
UPDATE t SET x = 3;
/* connection 1 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: msg: START TRANSACTION
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: COMMIT

-- # A row that wasn't changed by anything else can be changed, and the change
-- # is seen once it's committed.
/* connection 1 */
CREATE TABLE t (id INT PRIMARY KEY, x INT);
INSERT INTO t (id, x) VALUES (1, 1), (2, 2);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
UPDATE t SET x = 10 WHERE id = 1;
/* connection 2 */
UPDATE t SET x = 20 WHERE id = 2;
SELECT * FROM t;
/* connection 1 */
SELECT * FROM t;
COMMIT;
/* connection 2 */
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 1: msg: START TRANSACTION
-- 1: msg: UPDATE 1
-- 2: msg: UPDATE 1
-- 2: ID: 1 X: 1
-- 2: ID: 2 X: 20
-- 1: ID: 1 X: 10
-- 1: ID: 2 X: 2
-- 1: msg: COMMIT
-- 2: ID: 1 X: 10
-- 2: ID: 2 X: 20

-- # A row is found by its PRIMARY KEY (or an index) in the snapshot too.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (id INT PRIMARY KEY, x INT);
CREATE INDEX t_x ON t (x);
INSERT INTO t (id, x) VALUES (1, 1), (2, 2);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
UPDATE t SET x = 3 WHERE id = 1;
INSERT INTO t (id, x) VALUES (3, 1);
DELETE FROM t WHERE id = 2;
/* connection 1 */
SELECT * FROM t WHERE id = 1;
SELECT * FROM t WHERE id = 2;
SELECT * FROM t WHERE id = 3;
SELECT * FROM t WHERE x = 1;
SELECT * FROM t WHERE x = 3;
COMMIT;
SELECT * FROM t WHERE x = 1;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE INDEX 1
-- 1: msg: INSERT 2
-- 1: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 2: msg: INSERT 1
-- 2: msg: DELETE 1
-- 1: ID: 1 X: 1
-- 1: ID: 2 X: 2
-- 1: ID: 1 X: 1
-- 1: msg: COMMIT
-- 1: ID: 3 X: 1

-- # A row with the same PRIMARY KEY that another transaction inserted after the
-- # snapshot isn't seen, but it can't be inserted again.
/* connection 1 */
CREATE TABLE t (id INT PRIMARY KEY);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
INSERT INTO t (id) VALUES (1);
/* connection 1 */
SELECT * FROM t;
INSERT INTO t (id) VALUES (1);
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row

-- # Snapshot isolation isn't serializable. Each transaction reads both rows,
-- # and changes the row the other one read, so neither sees the other's
-- # change, which can't happen when one runs after the other (write skew). It
-- # isn't one of the phenomena that REPEATABLE READ must prevent (4.41.4), but
-- # SERIALIZABLE doesn't allow it.
/* connection 1 */
CREATE TABLE doctors (name VARCHAR(10), on_call BOOLEAN);
INSERT INTO doctors (name, on_call) VALUES ('alice', TRUE), ('bob', TRUE);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) AS c FROM doctors WHERE on_call;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) AS c FROM doctors WHERE on_call;
UPDATE doctors SET on_call = FALSE WHERE name = 'bob';
COMMIT;
/* connection 1 */
UPDATE doctors SET on_call = FALSE WHERE name = 'alice';
COMMIT;
SELECT COUNT(*) AS c FROM doctors WHERE on_call;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 1: msg: START TRANSACTION
-- 1: C: 2
-- 2: msg: START TRANSACTION
-- 2: C: 2
-- 2: msg: UPDATE 1
-- 2: msg: COMMIT
-- 1: msg: UPDATE 1
-- 1: msg: COMMIT
-- 1: C: 0

/* connection 1 */
CREATE TABLE doctors (name VARCHAR(10), on_call BOOLEAN);
INSERT INTO doctors (name, on_call) VALUES ('alice', TRUE), ('bob', TRUE);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) AS c FROM doctors WHERE on_call;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 1 */
UPDATE doctors SET on_call = FALSE WHERE name = 'alice';
COMMIT;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) AS c FROM doctors WHERE on_call;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 1: msg: START TRANSACTION
-- 1: C: 2
-- 2: error 40001: serialization failure: another connection has a transaction that must finish first
-- 1: msg: UPDATE 1
-- 1: msg: COMMIT
-- 2: msg: START TRANSACTION
-- 2: C: 1
-- 2: msg: COMMIT

-- # COMMIT keeps the old version of a row while a snapshot can still see it. A
-- # row can only have two versions, so until then, another transaction can't
-- # change it again.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
UPDATE t SET x = 2;
UPDATE t SET x = 3;
/* connection 1 */
SELECT * FROM t;
COMMIT;
/* connection 2 */
UPDATE t SET x = 3;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: X: 1
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: X: 3

-- # A ROLLBACK doesn't keep them either.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 1 */
ROLLBACK;
/* connection 2 */
UPDATE t SET x = 3;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 1: msg: ROLLBACK
-- 2: msg: UPDATE 1
-- 2: X: 3

-- # A version is kept until every snapshot that can see it has finished. A
-- # snapshot that started after the change was committed can't see the old
-- # version.
/* connection 1 */
CREATE TABLE t (id INT PRIMARY KEY, x INT);
INSERT INTO t (id, x) VALUES (1, 1), (2, 1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
UPDATE t SET x = 2 WHERE id = 1;
/* connection 3 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
UPDATE t SET x = 2 WHERE id = 2;
/* connection 1 */
SELECT * FROM t;
COMMIT;
/* connection 2 */
UPDATE t SET x = 3 WHERE id = 1;
UPDATE t SET x = 3 WHERE id = 2;
/* connection 3 */
SELECT * FROM t;
COMMIT;
/* connection 2 */
UPDATE t SET x = 3 WHERE id = 2;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 2
-- 1: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 3: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 1: ID: 1 X: 1
-- 1: ID: 2 X: 1
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 3: ID: 1 X: 2
-- 3: ID: 2 X: 1
-- 3: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: ID: 1 X: 3
-- 2: ID: 2 X: 3

-- # The same for a value that's stored across several pages.
/* connection 1 */
CREATE TABLE t (x VARCHAR(1000));
INSERT INTO t (x) VALUES ('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
UPDATE t SET x = 'b';
/* connection 1 */
SELECT CHARACTER_LENGTH(x) AS len FROM t;
COMMIT;
/* connection 2 */
UPDATE t SET x = 'c';
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 1: LEN: 300
-- 1: msg: COMMIT
-- 2: msg: UPDATE 1
-- 2: X: c

-- # A connection that stops in the middle of a REPEATABLE READ transaction
-- # leaves its snapshot behind, until the transaction is rolled back when
-- # there are no other connections (see "Crashed Transactions" in
-- # docs/mvcc.rst).
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM t;
/* connection 2 */
UPDATE t SET x = 2;
/* connection 3 */
SELECT * FROM t;
/* disconnect 1 */
/* connection 2 */
UPDATE t SET x = 3;
/* disconnect 3 */
/* connection 2 */
UPDATE t SET x = 4;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: msg: UPDATE 1
-- 3: X: 2
-- 2: error 40001: serialization failure: avoiding concurrent write on individual row
-- 2: msg: UPDATE 1
-- 2: X: 4

-- # A REPEATABLE READ transaction can't commit while another connection has a
-- # SERIALIZABLE transaction, the same as READ COMMITTED (see
-- # std_2_17_3_isolation_serializable.sql). It doesn't wait to start, and it can
-- # read and change rows in the meantime.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM t;
INSERT INTO t (x) VALUES (2);
COMMIT;
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM t;
COMMIT;
/* connection 1 */
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: START TRANSACTION
-- 2: X: 1
-- 2: msg: INSERT 1
-- 2: error 40001: serialization failure: cannot commit while another connection has a SERIALIZABLE transaction
-- 2: msg: START TRANSACTION
-- 2: X: 1
-- 2: msg: COMMIT
-- 1: msg: COMMIT

-- # A SERIALIZABLE transaction doesn't wait for a REPEATABLE READ transaction.
/* connection 1 */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM t;
/* connection 2 */
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
UPDATE t SET x = 2;
COMMIT;
/* connection 1 */
SELECT * FROM t;
COMMIT;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 1: X: 1
-- 2: msg: START TRANSACTION
-- 2: msg: UPDATE 1
-- 2: msg: COMMIT
-- 1: X: 1
-- 1: msg: COMMIT

-- # The schema is part of the snapshot. A table that another transaction
-- # creates or drops after it started isn't seen (or is still seen), until it
-- # ends.
/* extensions V104-01 */
/* connection 1 */
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
CREATE TABLE t2 (x INT);
DROP TABLE t1;
/* connection 1 */
SELECT * FROM t1;
SELECT * FROM t2;
COMMIT;
SELECT * FROM t1;
SELECT * FROM t2;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: CREATE TABLE 1
-- 2: msg: DROP TABLE 1
-- 1: X: 1
-- 1: error 42P01: no such table: "test".PUBLIC.T2
-- 1: msg: COMMIT
-- 1: error 42P01: no such table: "test".PUBLIC.T1

-- # It can't change the schema once another transaction has changed it, because
-- # the names it can see aren't the latest ones.
/* connection 1 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
CREATE TABLE t (x INT);
/* connection 1 */
CREATE TABLE t (x INT);
-- 1: msg: START TRANSACTION
-- 2: msg: CREATE TABLE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on table "test".PUBLIC.T

/* connection 1 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
CREATE TABLE t1 (x INT);
CREATE TABLE t2 (x INT);
/* connection 2 */
CREATE SCHEMA s;
/* connection 1 */
CREATE TABLE t3 (x INT);
COMMIT;
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 2: msg: CREATE SCHEMA 1
-- 1: error 40001: serialization failure: avoiding concurrent change to the schema
-- 1: msg: COMMIT

-- # Its own changes to the schema are seen by others once it commits.
/* extensions V104-01 */
/* connection 1 */
CREATE TABLE t1 (x INT);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
CREATE TABLE t2 (x INT);
DROP TABLE t1;
/* connection 2 */
SELECT * FROM t1;
SELECT * FROM t2;
/* connection 1 */
COMMIT;
/* connection 2 */
SELECT * FROM t1;
SELECT * FROM t2;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: DROP TABLE 1
-- 2: error 42P01: no such table: "test".PUBLIC.T2
-- 1: msg: COMMIT
-- 2: error 42P01: no such table: "test".PUBLIC.T1

-- # A row can't be written to a table that another transaction has changed
-- # since the snapshot, such as adding a column or an index that the row
-- # would need to have.
/* extensions V002-01 */
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
CREATE INDEX t_x ON t (x);
/* connection 1 */
INSERT INTO t (x) VALUES (1);
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: msg: CREATE INDEX 1
-- 1: error 40001: serialization failure: avoiding concurrent write on table definition

/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
ALTER TABLE t ADD COLUMN y INT;
/* connection 1 */
INSERT INTO t (x) VALUES (1);
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: msg: ALTER TABLE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on table definition

-- # A FOREIGN KEY is checked against the latest rows: a row that another
-- # transaction deleted (or inserted) since the snapshot is a serialization
-- # failure, rather than being seen (or not) in the snapshot.
/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent (id));
INSERT INTO parent (id) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
DELETE FROM parent;
INSERT INTO parent (id) VALUES (2);
/* connection 1 */
SELECT * FROM parent;
INSERT INTO child (parent_id) VALUES (1);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO child (parent_id) VALUES (2);
COMMIT;
SELECT * FROM child;
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 1: msg: START TRANSACTION
-- 2: msg: DELETE 1
-- 2: msg: INSERT 1
-- 1: ID: 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 1: PARENT_ID: 2

/* connection 1 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent (id));
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
INSERT INTO parent (id) VALUES (1);
/* connection 1 */
INSERT INTO child (parent_id) VALUES (1);
-- 1: msg: CREATE TABLE 1
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: msg: INSERT 1
-- 1: error 40001: serialization failure: avoiding concurrent write on individual row

-- # The value of a sequence isn't part of any transaction (4.27.2), so NEXT
-- # VALUE FOR uses the latest value, not the one in the snapshot.
/* connection 1 */
CREATE SEQUENCE s;
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
/* connection 2 */
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
/* connection 1 */
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
COMMIT;
-- 1: msg: CREATE SEQUENCE 1
-- 1: msg: START TRANSACTION
-- 1: COL1: 1
-- 2: COL1: 2
-- 1: COL1: 3
-- 1: msg: COMMIT

/* connection 1 */
CREATE TABLE t (id INT GENERATED ALWAYS AS IDENTITY, x INT);
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO t (x) VALUES (1);
/* connection 2 */
INSERT INTO t (x) VALUES (2);
/* connection 1 */
INSERT INTO t (x) VALUES (3);
COMMIT;
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 1: msg: INSERT 1
-- 2: msg: INSERT 1
-- 1: msg: INSERT 1
-- 1: msg: COMMIT
-- 1: ID: 1 X: 1
-- 1: ID: 2 X: 2
-- 1: ID: 3 X: 3

-- # A sequence that another transaction drops (or creates) after the snapshot
-- # is a serialization failure.
/* extensions V107-01 */
/* connection 1 */
CREATE SEQUENCE s;
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
DROP SEQUENCE s;
CREATE SEQUENCE s2;
/* connection 1 */
SELECT NEXT VALUE FOR s FROM (VALUES 1) AS t;
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
DROP SEQUENCE s2;
/* connection 1 */
CREATE SEQUENCE s2;
-- 1: msg: CREATE SEQUENCE 1
-- 1: msg: START TRANSACTION
-- 2: msg: DROP SEQUENCE 1
-- 2: msg: CREATE SEQUENCE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on sequence
-- 1: msg: START TRANSACTION
-- 2: msg: DROP SEQUENCE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on sequence "test".PUBLIC.S2

/* connection 1 */
START TRANSACTION ISOLATION LEVEL REPEATABLE READ;
/* connection 2 */
CREATE SEQUENCE s;
/* connection 1 */
CREATE SEQUENCE s;
-- 1: msg: START TRANSACTION
-- 2: msg: CREATE SEQUENCE 1
-- 1: error 40001: serialization failure: avoiding concurrent write on sequence "test".PUBLIC.S

-- # A statement outside of a transaction at REPEATABLE READ is the same as READ
-- # COMMITTED: it doesn't wait for a SERIALIZABLE transaction, but it can't
-- # commit until it ends.
/* connection 1 */
CREATE TABLE t (x INT);
START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
/* connection 2 */
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO t (x) VALUES (1);
/* connection 1 */
COMMIT;
/* connection 2 */
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: START TRANSACTION
-- 2: msg: SET TRANSACTION
-- 2: error 40001: serialization failure: cannot commit while another connection has a SERIALIZABLE transaction
-- 1: msg: COMMIT
-- 2: msg: SET TRANSACTION
-- 2: msg: INSERT 1
-- 2: X: 1
