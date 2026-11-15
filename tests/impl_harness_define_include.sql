-- # The setup runs before every block. A define names a group of statements,
-- # which only run where they're included, in the order of the include
-- # directive.

/* define t */
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);

/* define a */
CREATE TABLE a (x INT);

/* define a_row */
INSERT INTO a (x) VALUES (2);

/* define a_with_row */
/* include a a_row */

/* include t */
SELECT * FROM t;
-- X: 1

/* include a */
SELECT COUNT(*) FROM a;
-- COL1: 0

/* include t */
/* include a a_row */
SELECT * FROM t JOIN a ON t.x < a.x;
-- X: 1 X: 2

-- # An include can be anywhere in a block, and its output isn't checked.
/* include a */
INSERT INTO a (x) VALUES (3);
/* include a_row */
SELECT * FROM a;
DROP TABLE a RESTRICT;
/* include a_with_row */
SELECT * FROM a;
-- msg: INSERT 1
-- X: 3
-- X: 2
-- msg: DROP TABLE 1
-- X: 2
