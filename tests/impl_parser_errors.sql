-- # A syntax error from the parser says which token wasn't expected, where it
-- # is (the line and column, from 1) and the text around it.
SELECT * FROM t WHERE x = = 1;
-- error 42601: syntax error: unexpected "=" at line 1, column 27 near "WHERE x = = 1"

-- # The end of the statement is after the last token.
SELECT * FROM t WHERE   ;
-- error 42601: syntax error: unexpected $end at line 1, column 22 near "* FROM t WHERE"

-- # The column counts characters, not bytes.
VALUES 'ü€', 'ö' FROM;
-- error 42601: syntax error: unexpected FROM at line 1, column 18 near "'ü€', 'ö' FROM"

-- # Semicolons at the start are counted.
;;SELECT * FROM;
-- error 42601: syntax error: unexpected $end at line 1, column 16 near "SELECT * FROM"

-- # The line is counted from the start of the statement, and the text is only
-- # from the same line.
CREATE TABLE products (
  id INTEGER,
  name VARCHAR(100)
  price NUMERIC(10, 2)
);
-- error 42601: syntax error: unexpected identifier at line 4, column 3 near "price NUMERIC", expecting ")" or ","; hint: is a "," missing before price?

SELECT x, FROM
t;
-- error 42601: syntax error: unexpected FROM at line 1, column 11 near "SELECT x, FROM"; hint: remove the "," before FROM

-- # White space in the text is one space, and the text is shortened when it's
-- # long, leaving out the furthest tokens first.
SELECT    *    FROM    t    WHERE    x    =    =    1;
-- error 42601: syntax error: unexpected "=" at line 1, column 48 near "WHERE x = = 1"

VALUES 1234567890 abcdefghijklmnopqrstuvwxyzabcd efghijklmnopq;
-- error 42601: syntax error: unexpected identifier at line 1, column 19 near "abcdefghijklmnopqrstuvwxyzabcd"

VALUES 1 'abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz';
-- error 42601: syntax error: unexpected string at line 1, column 10 near "'abcdefghijklmnopqrstuvwxyzabcdefghij..."; hint: is a "," missing before 'abcdefghijklmnopqrstuvwxyzabcdefghij...?

-- # A token that's made from more than one token has the position of all of
-- # them.
SELECT t.* * FROM t;
-- error 42601: syntax error: unexpected "*" at line 1, column 12 near "SELECT t.* * FROM"

SELECT x FROM t WHERE x IS NOT TRUE TRUE;
-- error 42601: syntax error: unexpected TRUE at line 1, column 37 near "WHERE x IS NOT TRUE TRUE"

SELECT NOW() NOW() FROM t;
-- error 42601: syntax error: unexpected "(" at line 1, column 17 near "() NOW()"

SELECT x FROM t LIMIT 1 LIMIT 2;
-- error 42601: syntax error: unexpected LIMIT at line 1, column 25 near "t LIMIT 1 LIMIT 2"

SELECT x FROM t WHERE x ILIKE 'a' ILIKE 'b';
-- error 42601: syntax error: unexpected ILIKE at line 1, column 35 near "x ILIKE 'a' ILIKE 'b'"

-- # A hint is given for some common mistakes. A reserved word must be quoted
-- # to be a name.
CREATE TABLE t (id INT, order INT);
-- error 42601: syntax error: unexpected ORDER at line 1, column 25 near "id INT, order INT"; hint: ORDER is a reserved word, so it must be quoted to be used as a name, such as "ORDER" (see https://vsql.readthedocs.io/en/latest/keywords.html)

-- # But not a word that is a value, because it's more likely to be in the
-- # wrong place.
VALUES (1 NULL);
-- error 42601: syntax error: unexpected NULL at line 1, column 11 near "VALUES (1 NULL)", expecting ","

-- # The hint is only given if it would fix the error.
SELECT * FROM t ORDER ORDER BY x;
-- error 42601: syntax error: unexpected ORDER at line 1, column 23 near "FROM t ORDER ORDER BY", expecting BY

-- # A comma is missing.
CREATE TABLE t (a INT b INT);
-- error 42601: syntax error: unexpected identifier at line 1, column 23 near "(a INT b INT", expecting ")" or ","; hint: is a "," missing before b?

SELECT * FROM t WHERE x IN (1 2);
-- error 42601: syntax error: unexpected number at line 1, column 31 near "IN (1 2)", expecting ")" or ","; hint: is a "," missing before 2?

-- # But not if the tokens aren't separated, or the comma doesn't fix it.
VALUES 1.e;
-- error 42601: syntax error: unexpected identifier at line 1, column 10 near "VALUES 1.e"

SELECT * FROM t WHERE x = 1 y = 2;
-- error 42601: syntax error: unexpected identifier at line 1, column 29 near "x = 1 y ="

-- # A comma at the end of a list.
SELECT x, FROM t;
-- error 42601: syntax error: unexpected FROM at line 1, column 11 near "SELECT x, FROM t"; hint: remove the "," before FROM

CREATE TABLE t (a INT,);
-- error 42601: syntax error: unexpected ")" at line 1, column 23 near "a INT,)"; hint: remove the "," before )

SELECT * FROM t,;
-- error 42601: syntax error: unexpected $end at line 1, column 17 near "* FROM t,"; hint: remove the "," at the end

-- # The columns of a PRIMARY KEY or UNIQUE table constraint are in
-- # parentheses.
CREATE TABLE t (id INT, PRIMARY KEY id);
-- error 42601: syntax error: unexpected identifier at line 1, column 37 near ", PRIMARY KEY id)", expecting "("; hint: the columns of a PRIMARY KEY table constraint must be in parentheses, such as PRIMARY KEY (id), or it can be written on the column, such as id INTEGER PRIMARY KEY (see https://vsql.readthedocs.io/en/latest/create-table.html#primary-keys)

CREATE TABLE t (id INT, code INT, UNIQUE code);
-- error 42601: syntax error: unexpected identifier at line 1, column 42 near "INT, UNIQUE code)", expecting "("; hint: the columns of a UNIQUE table constraint must be in parentheses, such as UNIQUE (code), or it can be written on the column, such as code INTEGER UNIQUE (see https://vsql.readthedocs.io/en/latest/create-table.html#unique-constraints)

-- # The DEFAULT must be before the constraints of a column.
CREATE TABLE t (id INT PRIMARY KEY DEFAULT 1);
-- error 42601: syntax error: unexpected DEFAULT at line 1, column 36 near "INT PRIMARY KEY DEFAULT 1", expecting ")" or ","; hint: the DEFAULT of a column must be before its constraints, such as x INTEGER DEFAULT 0 NOT NULL (see https://vsql.readthedocs.io/en/latest/create-table.html#defaults)

CREATE TABLE t (id INT CHECK (id > 0) DEFAULT 1);
-- error 42601: syntax error: unexpected DEFAULT at line 1, column 39 near "> 0) DEFAULT 1", expecting ")" or ","; hint: the DEFAULT of a column must be before its constraints, such as x INTEGER DEFAULT 0 NOT NULL (see https://vsql.readthedocs.io/en/latest/create-table.html#defaults)

ALTER TABLE t ADD COLUMN c INT UNIQUE DEFAULT 1;
-- error 42601: syntax error: unexpected DEFAULT at line 1, column 39 near "c INT UNIQUE DEFAULT 1"; hint: the DEFAULT of a column must be before its constraints, such as x INTEGER DEFAULT 0 NOT NULL (see https://vsql.readthedocs.io/en/latest/create-table.html#defaults)

-- # But it's not a column anywhere else.
SELECT * FROM (VALUES 1) AS v (x) DEFAULT;
-- error 42601: syntax error: unexpected DEFAULT at line 1, column 35 near "(x) DEFAULT"

-- # A column that is numbered automatically is an identity column.
CREATE TABLE t (id INT AUTO_INCREMENT PRIMARY KEY);
-- error 42601: syntax error: unexpected identifier at line 1, column 24 near "(id INT AUTO_INCREMENT PRIMARY", expecting ")" or ","; hint: use GENERATED BY DEFAULT AS IDENTITY for a column that is numbered automatically, such as id INTEGER GENERATED BY DEFAULT AS IDENTITY (see https://vsql.readthedocs.io/en/latest/create-table.html#identity-columns)

CREATE TABLE t (id INTEGER PRIMARY KEY AUTOINCREMENT);
-- error 42601: syntax error: unexpected identifier at line 1, column 40 near "INTEGER PRIMARY KEY AUTOINCREMENT)", expecting ")" or ","; hint: use GENERATED BY DEFAULT AS IDENTITY for a column that is numbered automatically, such as id INTEGER GENERATED BY DEFAULT AS IDENTITY (see https://vsql.readthedocs.io/en/latest/create-table.html#identity-columns)

CREATE TABLE t (id serial);
-- error 42601: syntax error: unexpected identifier at line 1, column 20 near "t (id serial)"; hint: use GENERATED BY DEFAULT AS IDENTITY for a column that is numbered automatically, such as id INTEGER GENERATED BY DEFAULT AS IDENTITY (see https://vsql.readthedocs.io/en/latest/create-table.html#identity-columns)

-- # TOP isn't supported.
SELECT TOP 5 * FROM t;
-- error 42601: syntax error: unexpected number at line 1, column 12 near "SELECT TOP 5 *"; hint: TOP is not supported, use FETCH FIRST 5 ROWS ONLY at the end of the query

-- # A statement without any tokens doesn't have a position.
EXPLAIN /* nothing */;
-- error 42601: syntax error: unexpected $end
