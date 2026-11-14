-- # TEXT is a vsql extension (V601-01), which is the same as a CHARACTER
-- # VARYING without a length (T081), so it has the maximum length.
/* extensions V601-01 */
/* types */
/* flags */
CREATE TABLE t (a TEXT);
INSERT INTO t (a) VALUES ('hello');
SELECT a, CAST(1 AS TEXT) FROM t;
-- flags: V601-01
-- msg: CREATE TABLE 1
-- flags:
-- msg: INSERT 1
-- flags: V601-01
-- A: hello (CHARACTER VARYING(10485760)) COL2: 1 (CHARACTER VARYING(10485760))

-- # TEXT isn't a reserved word, so it can still be a name.
/* extensions V601-01 */
CREATE TABLE text (text TEXT);
INSERT INTO text (text) VALUES ('a');
SELECT text FROM text;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- TEXT: a
