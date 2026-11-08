-- # DROP SEQUENCE IF EXISTS is a vsql extension (V107-02).

-- # A sequence that doesn't exist isn't an error (DROP SEQUENCE 0), with or
-- # without RESTRICT or CASCADE. One that does is dropped (DROP SEQUENCE 1).
/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS s;
DROP SEQUENCE IF EXISTS s RESTRICT;
DROP SEQUENCE IF EXISTS s CASCADE;
-- msg: DROP SEQUENCE 0
-- msg: DROP SEQUENCE 0
-- msg: DROP SEQUENCE 0

/* extensions V107-01 V107-02 */
CREATE SEQUENCE s;
DROP SEQUENCE IF EXISTS s;
DROP SEQUENCE IF EXISTS s;
CREATE SEQUENCE s;
DROP SEQUENCE IF EXISTS s CASCADE;
DROP SEQUENCE s;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- msg: DROP SEQUENCE 0
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- error 42P01: no such sequence: ":memory:".PUBLIC.S

-- # A sequence in a schema that doesn't exist doesn't exist either, which is
-- # an error without IF EXISTS. A catalog that doesn't exist is still an error,
-- # and so is the read-only INFORMATION_SCHEMA.
/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS nosuch.s;
-- msg: DROP SEQUENCE 0

DROP SEQUENCE nosuch.s RESTRICT;
-- error 3F000: invalid schema name: NOSUCH

/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS nosuch.public.s;
-- error 3D000: invalid catalog name: NOSUCH

/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS information_schema.s;
-- error 42501: insufficient privilege: INFORMATION_SCHEMA is read-only

-- # A sequence in another schema doesn't count, and neither does a table.
/* extensions V107-01 V107-02 */
CREATE SCHEMA other;
CREATE SEQUENCE other.s;
CREATE TABLE s (x INT);
DROP SEQUENCE IF EXISTS s;
SELECT * FROM s;
DROP SEQUENCE IF EXISTS other.s;
-- msg: CREATE SCHEMA 1
-- msg: CREATE SEQUENCE 1
-- msg: CREATE TABLE 1
-- msg: DROP SEQUENCE 0
-- msg: DROP SEQUENCE 1

-- # Whether it exists is what this transaction can see: a drop earlier in the
-- # transaction counts until ROLLBACK, and a sequence that another connection
-- # has dropped doesn't exist.
/* extensions V107-01 V107-02 */
CREATE SEQUENCE s;
START TRANSACTION;
DROP SEQUENCE s;
DROP SEQUENCE IF EXISTS s;
ROLLBACK;
DROP SEQUENCE IF EXISTS s;
-- msg: CREATE SEQUENCE 1
-- msg: START TRANSACTION
-- msg: DROP SEQUENCE 1
-- msg: DROP SEQUENCE 0
-- msg: ROLLBACK
-- msg: DROP SEQUENCE 1

/* connection 1 */
CREATE SEQUENCE s;
DROP SEQUENCE s RESTRICT;
/* connection 2 */
/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS s;
-- 1: msg: CREATE SEQUENCE 1
-- 1: msg: DROP SEQUENCE 1
-- 2: msg: DROP SEQUENCE 0

-- # IF isn't a reserved word, so it can still be a sequence name.
/* extensions V107-01 V107-02 */
CREATE SEQUENCE if;
DROP SEQUENCE if;
DROP SEQUENCE IF EXISTS if;
CREATE SEQUENCE if;
DROP SEQUENCE if RESTRICT;
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1
-- msg: DROP SEQUENCE 0
-- msg: CREATE SEQUENCE 1
-- msg: DROP SEQUENCE 1

-- # Flagging: only the form that's used, and not the standard forms.

/* flags */
DROP SEQUENCE s RESTRICT;
-- flags: T176
-- error 42P01: no such sequence: ":memory:".PUBLIC.S

/* flags */
/* extensions V107-01 V107-02 */
DROP SEQUENCE IF EXISTS s;
-- flags: T176, V107-01, V107-02
-- msg: DROP SEQUENCE 0

/* flags */
/* extensions V107-02 */
DROP SEQUENCE IF EXISTS s CASCADE;
-- flags: T176, V107-02
-- msg: DROP SEQUENCE 0
