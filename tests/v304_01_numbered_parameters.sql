-- # $1, $2, etc. are numbered parameters, the PostgreSQL form of a dynamic
-- # parameter (V304-01). $n is the parameter value ?n.
/* extensions V304-01 */
/* types */
/* params 'a' 2 */
VALUES ROW(CAST($1 AS VARCHAR(1)), CAST($2 AS INT));
-- sql: VALUES ROW(CAST('a' AS VARCHAR(1)), CAST(2.0e0 AS INT))
-- COL1: a (CHARACTER VARYING(1)) COL2: 2 (INTEGER)

-- # It's flagged, unlike a ?.
/* extensions V304-01 */
/* flags */
/* params 2 */
VALUES CAST($1 AS INT);
-- sql: VALUES CAST(2.0e0 AS INT)
-- flags: B031, F641, F661, V304-01
-- COL1: 2

/* flags */
/* params 2 */
VALUES CAST(? AS INT);
-- sql: VALUES CAST(2.0e0 AS INT)
-- flags: B031, F641, F661
-- COL1: 2

-- # The order of the numbers doesn't matter, and the same $n can be used more
-- # than once for the same value. Its type is from where it's first used.
/* extensions V304-01 */
/* types */
/* params 'a' 3 */
VALUES ROW(CAST($2 AS INT), CAST($1 AS VARCHAR(1)), $2 + 1, $1 || $1);
-- sql: VALUES ROW(CAST(3.0e0 AS INT), CAST('a' AS VARCHAR(1)), 3.0e0 + 1, 'a' || 'a')
-- COL1: 3 (INTEGER) COL2: a (CHARACTER VARYING(1)) COL3: 4 (INTEGER) COL4: aa (CHARACTER VARYING(2))

-- # Leading zeros are ignored.
/* extensions V304-01 */
/* params 5 */
VALUES CAST($01 AS INT);
-- sql: VALUES CAST(5.0e0 AS INT)
-- COL1: 5

/* define t */
CREATE TABLE t (shop VARCHAR(10), parent VARCHAR(10), enabled BOOLEAN);
INSERT INTO t VALUES ('a', 'b', FALSE), ('b', 'a', FALSE), ('c', 'c', FALSE);

/* include t */
/* extensions V304-01 */
/* params 'a' 'TRUE' */
UPDATE t SET enabled = $2 WHERE shop = $1 OR parent = $1;
SELECT * FROM t;
-- sql: UPDATE t SET enabled = 'TRUE' WHERE shop = 'a' OR parent = 'a'
-- msg: UPDATE 2
-- SHOP: a PARENT: b ENABLED: TRUE
-- SHOP: b PARENT: a ENABLED: TRUE
-- SHOP: c PARENT: c ENABLED: FALSE

-- # A number that's missed out is still a parameter, so it still needs a value.
/* extensions V304-01 */
/* params 'x' 'y' */
VALUES CAST($2 AS VARCHAR(1));
-- sql: VALUES CAST('y' AS VARCHAR(1))
-- COL1: y

/* extensions V304-01 */
/* params 'x' */
VALUES CAST($2 AS VARCHAR(1));
-- error 42P02: parameter does not exist: ?2

-- # A statement can't use both ? and $n.
VALUES CAST($1 AS INT), CAST(? AS INT);
VALUES CAST(? AS INT), CAST($1 AS INT);
-- error 42601: syntax error: cannot use both ? and $n parameters in a statement
-- error 42601: syntax error: cannot use both ? and $n parameters in a statement

-- # n must be from 1 to 65535.
VALUES $0;
VALUES $00;
VALUES $65536;
VALUES $1000000000000;
-- error 42601: syntax error: invalid parameter: $0
-- error 42601: syntax error: invalid parameter: $00
-- error 42601: syntax error: invalid parameter: $65536
-- error 42601: syntax error: invalid parameter: $1000000000000

/* extensions V304-01 */
/* params 7 */
VALUES CAST($65535 AS INT);
-- error 42P02: parameter does not exist: ?65535

-- # A $ in a string, or that isn't followed by a digit, isn't a parameter.
/* params 'a' */
VALUES '$1';
VALUES $a;
-- COL1: $1
-- error 42601: syntax error: invalid character: $
