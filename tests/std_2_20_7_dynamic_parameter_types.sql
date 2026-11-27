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

-- # The value is cast to the type of the column before it's stored, so a
-- # string that's too long is cut with a warning, rather than being an error
-- # like the same literal would be.
/* params 'abcdefghijk' */
INSERT INTO t (x, s) VALUES (5, ?);
SELECT s FROM t WHERE x = 5;
-- sql: INSERT INTO t (x, s) VALUES (5, 'abcdefghijk')
-- warning 01004: string data, right truncation
-- msg: INSERT 1
-- S: abcdefghij

-- # A comparison only uses the start of a value that's too long.
/* params 'abcdefghijk' */
INSERT INTO t (s) VALUES ('abcdefghij');
SELECT s FROM t WHERE s = ?;
-- msg: INSERT 1
-- sql: SELECT s FROM t WHERE s = 'abcdefghijk'
-- warning 01004: string data, right truncation
-- S: abcdefghij

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
SELECT ? FROM t;
VALUES -?;
VALUES ? IS NULL;
VALUES ABS(?);
VALUES COUNT(?);
-- error 42601: syntax error: the data type of ?1 cannot be determined
-- error 42601: syntax error: the data type of ?1 cannot be determined
-- error 42601: syntax error: the data type of ?1 cannot be determined
-- error 42601: syntax error: the data type of ?1 cannot be determined
-- error 42601: syntax error: the data type of ?1 cannot be determined
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
-- COL1: 1 (INTEGER)
-- COL1: 2 (INTEGER)

-- # The functions with their own rules, the start position and length of a
-- # SUBSTRING, and the arguments of OVERLAY.
/* types */
/* params 'abcde' 'ab' 'abcd' 7 3 */
VALUES ROW(CHAR_LENGTH(?), OCTET_LENGTH(?), POSITION(? IN 'xabcd'), MOD(?, 4), MOD(10, ?));
-- sql: VALUES ROW(CHAR_LENGTH('abcde'), OCTET_LENGTH('ab'), POSITION('abcd' IN 'xabcd'), MOD(7.0e0, 4), MOD(10, 3.0e0))
-- COL1: 5 (INTEGER) COL2: 2 (INTEGER) COL3: 2 (INTEGER) COL4: 3 (INTEGER) COL5: 1 (INTEGER)

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

-- # The value of SET SCHEMA, SET CATALOG and SET NAMES is a CHARACTER VARYING,
-- # so a number is cast to a character string, which isn't a schema.
/* params 'PUBLIC' */
SET SCHEMA ?;
-- sql: SET SCHEMA 'PUBLIC'
-- msg: SET SCHEMA 1

/* params 1.5 */
SET SCHEMA ?;
-- sql: SET SCHEMA 1.5e0
-- error 3F000: invalid schema name: 1.5E0

/* params 1.5 */
SET CATALOG ?;
-- sql: SET CATALOG 1.5e0
-- error 3D000: invalid catalog name: 1.5E0

/* params 1.5 */
SET NAMES ?;
-- sql: SET NAMES 1.5e0
-- error 2C000: invalid character set name: 1.5E0

-- # The value, pattern and escape character of a SUBSTRING ... SIMILAR are
-- # character strings, as long as one of them isn't a dynamic parameter.
/* types */
/* params 'a#"b#"c' */
VALUES SUBSTRING('abc' SIMILAR ? ESCAPE '#');
-- sql: VALUES SUBSTRING('abc' SIMILAR 'a#"b#"c' ESCAPE '#')
-- COL1: b (CHARACTER VARYING(3))

/* types */
/* params 'abc' */
VALUES SUBSTRING(? SIMILAR 'a#"b#"c' ESCAPE '#');
-- sql: VALUES SUBSTRING('abc' SIMILAR 'a#"b#"c' ESCAPE '#')
-- COL1: b (CHARACTER VARYING(10485760))

/* params '#' */
VALUES SUBSTRING('abc' SIMILAR 'a#"b#"c' ESCAPE ?);
-- sql: VALUES SUBSTRING('abc' SIMILAR 'a#"b#"c' ESCAPE '#')
-- COL1: b

/* params 'abc' 'a#"b#"c' '#' */
VALUES SUBSTRING(? SIMILAR ? ESCAPE ?);
-- sql: VALUES SUBSTRING('abc' SIMILAR 'a#"b#"c' ESCAPE '#')
-- error 42601: syntax error: the data type of ?1 cannot be determined

-- # A VALUES that's in parentheses, or an operand of a set operator, in an
-- # INSERT also has the types of the columns. A SELECT doesn't.
/* params '5' */
INSERT INTO t (x) (VALUES (?));
SELECT * FROM t WHERE x = 5;
-- sql: INSERT INTO t (x) (VALUES ('5'))
-- msg: INSERT 1
-- X: 5 S: NULL B: UNKNOWN

/* params '6' 7 */
INSERT INTO t (x, s) VALUES (?, 'six') UNION VALUES (7, ?);
SELECT * FROM t WHERE x > 5;
-- sql: INSERT INTO t (x, s) VALUES ('6', 'six') UNION VALUES (7, 7.0e0)
-- msg: INSERT 2
-- X: 6 S: six B: UNKNOWN
-- X: 7 S: 7.0E0 B: UNKNOWN

/* params 'false' */
INSERT INTO t (b) VALUES ? OR FALSE EXCEPT VALUES TRUE;
SELECT * FROM t WHERE x IS NULL;
-- sql: INSERT INTO t (b) VALUES 'false' OR FALSE EXCEPT VALUES TRUE
-- msg: INSERT 1
-- X: NULL S: NULL B: FALSE

/* params 10 */
INSERT INTO t (x) SELECT ? FROM t;
-- sql: INSERT INTO t (x) SELECT 10.0e0 FROM t
-- error 42601: syntax error: the data type of ?1 cannot be determined

-- # A value whose type can never be cast to the type of the dynamic parameter
-- # is a restricted data type attribute violation.
/* params 1.5 */
VALUES CAST(? AS DATE);
-- sql: VALUES CAST(1.5e0 AS DATE)
-- error 07006: restricted data type attribute violation: cannot cast DOUBLE PRECISION to DATE

-- # The statement must be valid to determine the types, otherwise the error is
-- # when it's executed.
/* params 1 */
SELECT x FROM missing WHERE x = ?;
-- sql: SELECT x FROM missing WHERE x = 1.0e0
-- error 42P01: no such table: ":memory:".PUBLIC.MISSING
