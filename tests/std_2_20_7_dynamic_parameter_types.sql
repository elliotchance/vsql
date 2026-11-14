-- # The data type of a dynamic parameter is determined from where it's used
-- # when the statement is prepared, and its value is cast to that type. A
-- # number in params is a DOUBLE PRECISION, and a string is a CHARACTER.
/* setup */
CREATE TABLE t (x INT, s VARCHAR(10), b BOOLEAN);
INSERT INTO t (x, s, b) VALUES (1, 'one', TRUE), (2, 'two', FALSE);

-- # A comparison with a column has the type of the column, so the value is
-- # cast to an INTEGER.
/* params 2.4 */
SELECT x FROM t WHERE x = ?;
-- sql: SELECT x FROM t WHERE x = 2.4e0
-- X: 2

/* params '1' */
SELECT x FROM t WHERE ? = x;
-- sql: SELECT x FROM t WHERE '1' = x
-- X: 1

/* params 'abc' */
SELECT x FROM t WHERE x = ?;
-- sql: SELECT x FROM t WHERE x = 'abc'
-- error 22018: invalid character value for cast

-- # A value of a VALUES of an INSERT has the type of its column, and so does
-- # the value of a SET.
/* params '3' 3 */
INSERT INTO t (x, s) VALUES (?, ?);
SELECT * FROM t WHERE x = 3;
-- sql: INSERT INTO t (x, s) VALUES ('3', 3.0e0)
-- msg: INSERT 1
-- X: 3 S: 3.0E0 B: UNKNOWN

/* params 'false' */
UPDATE t SET b = ? WHERE x = 1;
SELECT * FROM t WHERE x = 1;
-- sql: UPDATE t SET b = 'false' WHERE x = 1
-- msg: UPDATE 1
-- X: 1 S: one B: FALSE

/* params 4 */
INSERT INTO t VALUES (?, 'four', NULL);
SELECT * FROM t WHERE x > 3;
-- sql: INSERT INTO t VALUES (4.0e0, 'four', NULL)
-- msg: INSERT 1
-- X: 4 S: four B: UNKNOWN

-- # 1.9 is cast to the INTEGER 1.
/* params 1.9 */
DELETE FROM t WHERE x >= ?;
-- sql: DELETE FROM t WHERE x >= 1.9e0
-- msg: DELETE 2

-- # A value without a column can't be given its type, but the INSERT fails
-- # anyway.
/* params 1 2 */
INSERT INTO t (x) VALUES (?, ?);
-- sql: INSERT INTO t (x) VALUES (1.0e0, 2.0e0)
-- error 42601: syntax error: INSERT has more values than columns

-- # The operand of a CAST has the type of the CAST.
/* types */
/* params '12' */
VALUES CAST(? AS INTEGER);
-- sql: VALUES CAST('12' AS INTEGER)
-- COL1: 12 (INTEGER)

-- # A dynamic parameter whose type can't be determined is a syntax error.
/* params 1 2 */
VALUES ? + ?;
-- sql: VALUES 1.0e0 + 2.0e0
-- error 42601: syntax error: the data type of ?1 cannot be determined

VALUES ?;
-- error 42601: syntax error: the data type of ?1 cannot be determined

SELECT ? FROM t;
-- error 42601: syntax error: the data type of ?1 cannot be determined

VALUES -?;
-- error 42601: syntax error: the data type of ?1 cannot be determined

VALUES ? IS NULL;
-- error 42601: syntax error: the data type of ?1 cannot be determined

VALUES ABS(?);
-- error 42601: syntax error: the data type of ?1 cannot be determined

VALUES COUNT(?);
-- error 42601: syntax error: the data type of ?1 cannot be determined

-- # A dynamic parameter in parentheses is the same. The error is only for the
-- # first one.
VALUES (?) = (?);
-- error 42601: syntax error: the data type of ?1 cannot be determined

-- # An operand of an arithmetic operator has the type of the other operand.
/* types */
/* params 2.5 2.5 2.5 2.5 */
SELECT x + ?, ? * x, x - ?, ? / x FROM t WHERE x = 1;
-- sql: SELECT x + 2.5e0, 2.5e0 * x, x - 2.5e0, 2.5e0 / x FROM t WHERE x = 1
-- COL1: 3 (INTEGER) COL2: 2 (INTEGER) COL3: -1 (INTEGER) COL4: 2 (INTEGER)

/* types */
/* params 2.5 */
SELECT x FROM t WHERE (? + 1) * 2 = 6;
-- sql: SELECT x FROM t WHERE (2.5e0 + 1) * 2 = 6
-- X: 1 (INTEGER)
-- X: 2 (INTEGER)

-- # An operand of a concatenation is a character string, if the other one is.
/* types */
/* params 2 2 */
SELECT s || ?, ? || s FROM t WHERE x = 1;
-- sql: SELECT s || 2.0e0, 2.0e0 || s FROM t WHERE x = 1
-- COL1: one2.0E0 (CHARACTER VARYING(10485760)) COL2: 2.0E0one (CHARACTER VARYING(10485760))

-- # A boolean operand is a BOOLEAN.
/* params 'true' 'false' */
SELECT x FROM t WHERE ? AND NOT ?;
-- sql: SELECT x FROM t WHERE 'true' AND NOT 'false'
-- X: 1
-- X: 2

/* params 'false' */
SELECT x FROM t WHERE b OR ? IS TRUE;
-- sql: SELECT x FROM t WHERE b OR 'false' IS TRUE
-- X: 1

/* params 'true' */
SELECT x FROM t WHERE ?;
-- sql: SELECT x FROM t WHERE 'true'
-- X: 1
-- X: 2

/* params 'true' */
SELECT x FROM t GROUP BY x HAVING ?;
-- sql: SELECT x FROM t GROUP BY x HAVING 'true'
-- X: 1
-- X: 2

/* params 'false' */
SELECT t.x FROM t JOIN t AS t2 ON ?;
-- sql: SELECT t.x FROM t JOIN t AS t2 ON 'false'

-- # BETWEEN, IN and a quantified comparison have the type of the other values.
/* params 1.4 '2' */
SELECT x FROM t WHERE x BETWEEN ? AND ?;
-- sql: SELECT x FROM t WHERE x BETWEEN 1.4e0 AND '2'
-- X: 1
-- X: 2

/* params 1.2 */
SELECT x FROM t WHERE ? BETWEEN x AND 2;
-- sql: SELECT x FROM t WHERE 1.2e0 BETWEEN x AND 2
-- X: 1

/* params '2' */
SELECT x FROM t WHERE x IN (5, ?);
-- sql: SELECT x FROM t WHERE x IN (5, '2')
-- X: 2

/* params 1.1 */
SELECT x FROM t WHERE ? IN (x, 3);
-- sql: SELECT x FROM t WHERE 1.1e0 IN (x, 3)
-- X: 1

/* params 1.1 */
SELECT x FROM t WHERE ? IN (SELECT x FROM t);
-- sql: SELECT x FROM t WHERE 1.1e0 IN (SELECT x FROM t)
-- X: 1
-- X: 2

/* params 1.9 */
SELECT x FROM t WHERE ? < ALL (SELECT x FROM t);
-- sql: SELECT x FROM t WHERE 1.9e0 < ALL (SELECT x FROM t)

-- # A row is compared one field at a time.
/* params '1' 'one' */
SELECT x FROM t WHERE (x, s) = (?, ?);
-- sql: SELECT x FROM t WHERE (x, s) = ('1', 'one')
-- X: 1

-- # LIKE and SIMILAR TO are character strings, even when they're all dynamic
-- # parameters.
/* params 't%' */
SELECT x FROM t WHERE s LIKE ?;
-- sql: SELECT x FROM t WHERE s LIKE 't%'
-- X: 2

/* params 'one' 'o%' '!' */
VALUES ? LIKE ? ESCAPE ?;
-- sql: VALUES 'one' LIKE 'o%' ESCAPE '!'
-- COL1: TRUE

/* params 'one' '(o|t)%' */
VALUES ? SIMILAR TO ?;
-- sql: VALUES 'one' SIMILAR TO '(o|t)%'
-- COL1: TRUE

-- # The results of a CASE, COALESCE and NULLIF have the type of the others, and
-- # so do the operand and values of a simple CASE.
/* types */
/* params 2.5 */
SELECT CASE WHEN x = 1 THEN ? ELSE x END FROM t;
-- sql: SELECT CASE WHEN x = 1 THEN 2.5e0 ELSE x END FROM t
-- COL1: 2 (INTEGER)
-- COL1: 2 (INTEGER)

/* types */
/* params 2.5 2.5 */
SELECT COALESCE(?, x), NULLIF(x, ?) FROM t WHERE x = 2;
-- sql: SELECT COALESCE(2.5e0, x), NULLIF(x, 2.5e0) FROM t WHERE x = 2
-- COL1: 2 (INTEGER) COL2: NULL (INTEGER)

/* params '1' 2 */
SELECT CASE ? WHEN x THEN 'yes' ELSE 'no' END, CASE x WHEN ? THEN 'yes' ELSE 'no' END FROM t;
-- sql: SELECT CASE '1' WHEN x THEN 'yes' ELSE 'no' END, CASE x WHEN 2.0e0 THEN 'yes' ELSE 'no' END FROM t
-- COL1: yes COL2: no
-- COL1: no  COL2: yes

/* params 'true' */
SELECT x FROM t WHERE CASE WHEN ? THEN b END;
-- sql: SELECT x FROM t WHERE CASE WHEN 'true' THEN b END
-- X: 1

-- # A row of a VALUES has the type of the other rows.
/* types */
/* params 2.5 */
VALUES 1, ?;
-- sql: VALUES 1, 2.5e0
-- COL1: 1 (SMALLINT)
-- COL1: 2 (SMALLINT)

-- # The functions with their own rules, the start position and length of a
-- # SUBSTRING, and the arguments of OVERLAY.
/* types */
/* params 'abcde' 'ab' 'abcd' 7 3 */
VALUES ROW(CHAR_LENGTH(?), OCTET_LENGTH(?), POSITION(? IN 'xabcd'), MOD(?, 4), MOD(10, ?));
-- sql: VALUES ROW(CHAR_LENGTH('abcde'), OCTET_LENGTH('ab'), POSITION('abcd' IN 'xabcd'), MOD(7.0e0, 4), MOD(10, 3.0e0))
-- COL1: 5 (INTEGER) COL2: 2 (INTEGER) COL3: 2 (INTEGER) COL4: 3 (SMALLINT) COL5: 1 (SMALLINT)

/* params 'xy' 2 1 */
VALUES OVERLAY('abc' PLACING ? FROM ? FOR ?);
-- sql: VALUES OVERLAY('abc' PLACING 'xy' FROM 2.0e0 FOR 1.0e0)
-- COL1: axyc

/* params 'abc' 'x' */
VALUES OVERLAY(? PLACING ? FROM 2);
-- sql: VALUES OVERLAY('abc' PLACING 'x' FROM 2)
-- error 42601: syntax error: the data type of ?1 cannot be determined

-- # Any other function has the type of its parameter, if there's only one
-- # function with that number of arguments.
/* types */
/* params 'Ab' */
VALUES UPPER(?);
-- sql: VALUES UPPER('Ab')
-- COL1: AB (CHARACTER VARYING(10485760))

-- # A NULL takes the type of the dynamic parameter.
/* params NULL BOOLEAN */
SELECT x FROM t WHERE x = ?;
-- sql: SELECT x FROM t WHERE x = CAST(NULL AS BOOLEAN)

-- # A statement that isn't a query, INSERT, UPDATE or DELETE isn't compiled, so
-- # its dynamic parameters have the type of their values.
/* params 'PUBLIC' */
SET SCHEMA ?;
-- sql: SET SCHEMA 'PUBLIC'
-- msg: SET SCHEMA 1

-- # The statement must be valid to determine the types, otherwise the error is
-- # when it's executed.
/* params 1 */
SELECT x FROM missing WHERE x = ?;
-- sql: SELECT x FROM missing WHERE x = 1.0e0
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING
