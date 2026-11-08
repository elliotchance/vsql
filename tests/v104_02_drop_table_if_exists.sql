-- # DROP TABLE IF EXISTS is a vsql extension (V104-02).

-- # A table that doesn't exist isn't an error (DROP TABLE 0), with or without
-- # RESTRICT or CASCADE. One that does is dropped (DROP TABLE 1).
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS t;
DROP TABLE IF EXISTS t RESTRICT;
DROP TABLE IF EXISTS t CASCADE;
-- msg: DROP TABLE 0
-- msg: DROP TABLE 0
-- msg: DROP TABLE 0

/* extensions V104-01 V104-02 */
CREATE TABLE t (x INT);
DROP TABLE IF EXISTS t;
SELECT * FROM t;
DROP TABLE IF EXISTS t;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- error 42P01: no such table: ":memory:".PUBLIC.T
-- msg: DROP TABLE 0

-- # A table in a schema that doesn't exist doesn't exist.
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS nosuch.t;
-- msg: DROP TABLE 0

-- # But a catalog that doesn't exist is still an error, and so is any table in
-- # the read-only INFORMATION_SCHEMA, even one that doesn't exist.
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS nosuch.public.t;
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS information_schema.tables;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS information_schema.nosuch;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # A virtual table can't be dropped, it's not a table for DROP TABLE.
/* virtual_table CREATE TABLE fruits (id INT) AS VALUES 1 */
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS fruits;
SELECT * FROM fruits;
-- msg: DROP TABLE 0
-- ID: 1

-- # A table in another schema doesn't count.
/* extensions V104-01 V104-02 */
CREATE SCHEMA other;
CREATE TABLE other.t (x INT);
DROP TABLE IF EXISTS t;
SELECT * FROM other.t;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 0

-- # If the table exists, RESTRICT (also the default) still fails when a
-- # FOREIGN KEY references it. CASCADE drops the table and the FOREIGN KEY, but
-- # not the child table, which then accepts any value.
/* extensions V104-01 V104-02 */
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (id INT, FOREIGN KEY (id) REFERENCES parent (id));
DROP TABLE IF EXISTS parent;
DROP TABLE IF EXISTS parent RESTRICT;
DROP TABLE IF EXISTS parent CASCADE;
INSERT INTO child (id) VALUES (1);
DROP TABLE IF EXISTS parent CASCADE;
-- msg: CREATE TABLE 1
-- msg: CREATE TABLE 1
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.PARENT
-- error 2BP01: dependent objects still exist on ":memory:".PUBLIC.PARENT
-- msg: DROP TABLE 1
-- msg: INSERT 1
-- msg: DROP TABLE 0

-- # Whether it exists is what this transaction can see: a table dropped or
-- # created earlier in the transaction counts, until ROLLBACK undoes it.
/* extensions V104-01 V104-02 */
CREATE TABLE t (x INT);
START TRANSACTION;
DROP TABLE t;
DROP TABLE IF EXISTS t;
ROLLBACK;
INSERT INTO t (x) VALUES (1);
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: DROP TABLE 1
-- msg: DROP TABLE 0
-- msg: ROLLBACK
-- msg: INSERT 1
-- X: 1

/* extensions V104-01 V104-02 */
CREATE TABLE t (x INT);
START TRANSACTION;
DROP TABLE IF EXISTS t;
ROLLBACK;
SELECT * FROM t;
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: DROP TABLE 1
-- msg: ROLLBACK

/* extensions V104-01 V104-02 */
START TRANSACTION;
CREATE TABLE t (x INT);
DROP TABLE IF EXISTS t;
DROP TABLE IF EXISTS t;
COMMIT;
SELECT * FROM t;
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- msg: DROP TABLE 0
-- msg: COMMIT
-- error 42P01: no such table: ":memory:".PUBLIC.T

-- # A table that another connection dropped doesn't exist.
/* connection 1 */
CREATE TABLE t (x INT);
DROP TABLE t;
/* connection 2 */
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS t;
-- 1: msg: CREATE TABLE 1
-- 1: msg: DROP TABLE 1
-- 2: msg: DROP TABLE 0

-- # IF isn't a reserved word, so it can still be a table name.
/* extensions V104-01 V104-02 */
CREATE TABLE if (x INT);
DROP TABLE if;
DROP TABLE IF EXISTS if;
CREATE TABLE if (x INT);
DROP TABLE if CASCADE;
CREATE TABLE if (x INT);
DROP TABLE IF EXISTS if CASCADE;
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- msg: DROP TABLE 0
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1

-- # IF NOT EXISTS is only for CREATE.
DROP TABLE IF NOT EXISTS t;
-- error 42601: syntax error: unexpected NOT

-- # Flagging: only the form that's used, and not the standard forms.

/* flags */
DROP TABLE t RESTRICT;
-- flags:
-- error 42P01: no such table: ":memory:".PUBLIC.T

/* flags */
/* extensions V104-01 V104-02 */
DROP TABLE IF EXISTS t;
-- flags: V104-01, V104-02
-- msg: DROP TABLE 0

/* flags */
/* extensions V104-02 */
DROP TABLE IF EXISTS t RESTRICT;
-- flags: V104-02
-- msg: DROP TABLE 0

/* flags */
/* extensions V104-02 */
DROP TABLE IF EXISTS t CASCADE;
-- flags: F032, V104-02
-- msg: DROP TABLE 0
