-- # DROP VIEW without RESTRICT or CASCADE is a vsql extension (V119-01). It's
-- # the same as RESTRICT.
/* extensions V119-01 */
CREATE TABLE t (x INT);
CREATE VIEW v AS SELECT x FROM t;
DROP VIEW v;
DROP VIEW v;
-- msg: CREATE TABLE 1
-- msg: CREATE VIEW 1
-- msg: DROP VIEW 1
-- error 42P01: no such view: ":memory:".PUBLIC.V

/* extensions V119-01 */
/* flags */
DROP VIEW v;
-- flags: V119-01
-- error 42P01: no such view: ":memory:".PUBLIC.V

/* flags */
DROP VIEW v CASCADE;
-- flags: F032
-- error 42P01: no such view: ":memory:".PUBLIC.V
