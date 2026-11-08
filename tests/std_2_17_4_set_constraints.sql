-- # A DEFERRABLE constraint is immediate until SET CONSTRAINTS defers it.
CREATE TABLE t (x INT CONSTRAINT u UNIQUE DEFERRABLE);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS u DEFERRED;
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS u IMMEDIATE;
DELETE FROM t WHERE x = 1;
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS u IMMEDIATE;
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: SET CONSTRAINTS
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: DELETE 2
-- msg: INSERT 1
-- msg: SET CONSTRAINTS
-- msg: COMMIT
-- X: 1

-- # When SET CONSTRAINTS IMMEDIATE fails, the constraint stays deferred.
CREATE TABLE t (x INT CONSTRAINT u UNIQUE DEFERRABLE);
INSERT INTO t (x) VALUES (1);
START TRANSACTION;
SET CONSTRAINTS u DEFERRED;
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS u IMMEDIATE;
INSERT INTO t (x) VALUES (1);
COMMIT;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: START TRANSACTION
-- msg: SET CONSTRAINTS
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: INSERT 1
-- error 40002: integrity constraint violation: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- X: 1

-- # SET CONSTRAINTS ALL only changes the deferrable constraints, and a
-- # constraint that's still deferred isn't checked by SET CONSTRAINTS
-- # IMMEDIATE for another one.
CREATE TABLE p (id INT PRIMARY KEY);
CREATE TABLE t (
  x INT NOT NULL UNIQUE REFERENCES p CHECK (x > 0),
  y INT CONSTRAINT u UNIQUE DEFERRABLE,
  z INT CONSTRAINT c CHECK (z > 0) DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT f FOREIGN KEY (y) REFERENCES p NOT DEFERRABLE
);
INSERT INTO p (id) VALUES (1), (2);
START TRANSACTION;
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO t (x, y, z) VALUES (1, 1, -1);
INSERT INTO t (x, y, z) VALUES (1, 1, 1);
INSERT INTO t (x, y, z) VALUES (4, 1, 1);
INSERT INTO t (x, y, z) VALUES (2, 4, 1);
INSERT INTO t (x, y, z) VALUES (-1, 1, 1);
SET CONSTRAINTS c IMMEDIATE;
UPDATE t SET z = 1;
SET CONSTRAINTS c IMMEDIATE;
SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: START TRANSACTION
-- msg: SET CONSTRAINTS
-- msg: INSERT 1
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- error 23503: violates foreign key constraint: FOREIGN KEY (X) REFERENCES ":memory:".PUBLIC.P (ID) on ":memory:".PUBLIC.T
-- error 23503: violates foreign key constraint: FOREIGN KEY (Y) REFERENCES ":memory:".PUBLIC.P (ID) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (X > 0) on ":memory:".PUBLIC.T
-- error 23514: violates check constraint: CHECK (Z > 0) DEFERRABLE INITIALLY IMMEDIATE on ":memory:".PUBLIC.T
-- msg: UPDATE 1
-- msg: SET CONSTRAINTS
-- msg: SET CONSTRAINTS
-- msg: COMMIT

-- # SET CONSTRAINTS outside of a transaction is for the next transaction.
CREATE TABLE t (x INT CONSTRAINT u UNIQUE DEFERRABLE);
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS s.u, u DEFERRED;
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK;
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42704: no such constraint: S.U
-- msg: START TRANSACTION
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: ROLLBACK

CREATE TABLE t (x INT CONSTRAINT u UNIQUE DEFERRABLE);
INSERT INTO t (x) VALUES (1);
SET CONSTRAINTS public.u, u DEFERRED;
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK;
START TRANSACTION;
INSERT INTO t (x) VALUES (1);
ROLLBACK;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: SET CONSTRAINTS
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- error 23505: violates unique constraint: UNIQUE (X) on ":memory:".PUBLIC.T
-- msg: ROLLBACK

-- # Only a deferrable constraint can be deferred.
CREATE TABLE t (
  x INT CONSTRAINT nn NOT NULL CONSTRAINT pk PRIMARY KEY,
  y INT CONSTRAINT u UNIQUE,
  z INT CONSTRAINT f REFERENCES t,
  CONSTRAINT c CHECK (z > 0) NOT DEFERRABLE
);
SET CONSTRAINTS nn DEFERRED;
SET CONSTRAINTS pk DEFERRED;
SET CONSTRAINTS u DEFERRED;
SET CONSTRAINTS f DEFERRED;
SET CONSTRAINTS c DEFERRED;
SET CONSTRAINTS nope DEFERRED;
SET CONSTRAINTS nope.public.c DEFERRED;
EXPLAIN SET CONSTRAINTS ALL DEFERRED;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: constraint NN is not DEFERRABLE
-- error 42601: syntax error: constraint PK is not DEFERRABLE
-- error 42601: syntax error: constraint U is not DEFERRABLE
-- error 42601: syntax error: constraint F is not DEFERRABLE
-- error 42601: syntax error: constraint C is not DEFERRABLE
-- error 42704: no such constraint: NOPE
-- error 42704: no such constraint: NOPE.PUBLIC.C
-- error 42601: syntax error: Cannot EXPLAIN SET CONSTRAINTS
