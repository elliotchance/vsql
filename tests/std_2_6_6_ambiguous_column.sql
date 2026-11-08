-- # An unqualified column name that's in more than one table of the FROM
-- # clause is ambiguous.
/* setup */
CREATE TABLE a (id INT, x INT);
CREATE TABLE b (id INT, y INT);
INSERT INTO a (id, x) VALUES (1, 10);
INSERT INTO b (id, y) VALUES (2, 20);

SELECT id FROM a JOIN b ON TRUE;
-- error 42702: ambiguous column: ID

SELECT x FROM a JOIN b ON TRUE WHERE id = 1;
-- error 42702: ambiguous column: ID

SELECT x FROM a JOIN b ON id = 1;
-- error 42702: ambiguous column: ID

SELECT x FROM a JOIN b ON TRUE ORDER BY id;
-- error 42702: ambiguous column: ID

SELECT COUNT(*) FROM a JOIN b ON TRUE GROUP BY id;
-- error 42702: ambiguous column: ID

SELECT a.id, b.id, x, y FROM a JOIN b ON TRUE ORDER BY a.id;
-- ID: 1 ID: 2 X: 10 Y: 20

SELECT x FROM a WHERE x > 100 ORDER BY nope;
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.NOPE
