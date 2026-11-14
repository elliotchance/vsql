-- # ILIKE is LIKE that ignores case (V302-01). It's a vsql extension. See also
-- # v302_01_ilike_names.sql for "ilike" used as a name.
/* setup */
CREATE TABLE t (x VARCHAR(10), y VARCHAR(10));
INSERT INTO t (x, y) VALUES ('Ab', 'aB');

-- # EXPLAIN shows ILIKE as it was written, including NOT and ESCAPE.
/* extensions V001-01 V302-01 */
EXPLAIN VALUES 'a' ILIKE 'A';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a' ILIKE 'A')

/* extensions V001-01 V302-01 */
EXPLAIN VALUES 'a%' NOT ILIKE 'A!%' ESCAPE '!';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a%' NOT ILIKE 'A!%' ESCAPE '!')

-- # Letters match whatever their case, but otherwise it's the same as LIKE:
-- # the whole value has to match, and a trailing space isn't ignored.
/* extensions V302-01 */
VALUES 'a' ILIKE 'A';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'A' ILIKE 'a';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'a' ILIKE 'a';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'a' ILIKE 'b';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'a' ILIKE 'aa';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'aa' ILIKE 'a';
-- COL1: FALSE

/* extensions V302-01 */
VALUES '' ILIKE '';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'a ' ILIKE 'a';
-- COL1: FALSE

-- # _ matches one character and % matches any number of them, ignoring case.
/* extensions V302-01 */
VALUES 'ABC' ILIKE 'a_C';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ABC' ILIKE 'a_';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'AxxB' ILIKE 'a%b';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'AxxC' ILIKE 'a%b';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'abab' ILIKE '%AB';
-- COL1: TRUE

/* extensions V302-01 */
VALUES '' ILIKE '%';
-- COL1: TRUE

/* extensions V302-01 */
VALUES '' ILIKE '_';
-- COL1: FALSE

-- # Characters match if UPPER or LOWER makes them the same, using the full
-- # Unicode case mappings (such as the final sigma, ǅ and dotless ı). Neither
-- # changes ⓐ, so it only matches itself, and İ lowercases to i with a
-- # combining dot, so it doesn't match a plain i.
/* extensions V302-01 */
VALUES 'ÉCOLE' ILIKE 'école';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'σ' ILIKE 'Σ';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ς' ILIKE 'Σ';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ς' ILIKE 'σ';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ǅ' ILIKE 'ǆ';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ǅ' ILIKE 'Ǆ';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'K' ILIKE 'k';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ı' ILIKE 'I';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ⓐ' ILIKE 'Ⓐ';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'İ' ILIKE 'i';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'İ' ILIKE 'i̇';
-- COL1: TRUE

-- # A full case mapping can turn one character into two, so ß matches SS and
-- # ﬁ matches FI. However, the wildcards work on the characters of the value:
-- # ß is one character for _, and % or _ can't match only part of it.
/* extensions V302-01 */
VALUES 'ß' ILIKE 'SS';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'SS' ILIKE 'ß';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ß' ILIKE 'ss';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'straße' ILIKE 'STRASSE';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'STRASSE' ILIKE 'straße';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ẞ' ILIKE 'ß';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ẞ' ILIKE 'ss';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ﬁ' ILIKE 'FI';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ß' ILIKE '_';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'SS' ILIKE '_';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'SS' ILIKE '__';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ß' ILIKE '__';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'aßb' ILIKE 'a_b';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'aßb' ILIKE 'a%b';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ß' ILIKE '%';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ß' ILIKE 's';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'ß' ILIKE 'S%';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'ß' ILIKE '%S';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'ß' ILIKE 'S_';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'ß' ILIKE '_S';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'aß' ILIKE 'as%';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'straße' ILIKE '%ASS%';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ßßx' ILIKE '%ssx';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'sßx' ILIKE '%ssx';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ßsx' ILIKE '%ssx';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'ßx' ILIKE '%x';
-- COL1: TRUE

-- # The keyword isn't case sensitive, and NOT ILIKE is the opposite.
/* extensions V302-01 */
VALUES 'a' ilike 'A';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'a' NOT ILIKE 'A';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'a' NOT ILIKE 'b';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ß' not ilike 'SS';
-- COL1: FALSE

-- # A NULL value, pattern or escape character makes it UNKNOWN, the same as
-- # LIKE (8.5, General Rules, 3.a).
/* extensions V302-01 */
VALUES CAST(NULL AS VARCHAR(1)) ILIKE 'a';
-- COL1: UNKNOWN

/* extensions V302-01 */
VALUES 'a' ILIKE CAST(NULL AS VARCHAR(1));
-- COL1: UNKNOWN

/* extensions V302-01 */
VALUES CAST(NULL AS VARCHAR(1)) NOT ILIKE 'a';
-- COL1: UNKNOWN

/* extensions V302-01 */
VALUES 'a' NOT ILIKE CAST(NULL AS VARCHAR(1));
-- COL1: UNKNOWN

/* extensions V302-01 */
VALUES 'a' ILIKE 'a' ESCAPE CAST(NULL AS VARCHAR(1));
-- COL1: UNKNOWN

/* extensions V302-01 */
VALUES 'a' NOT ILIKE 'a' ESCAPE CAST(NULL AS VARCHAR(1));
-- COL1: UNKNOWN

-- # The escape character is found before folding.

/* extensions V302-01 */
VALUES 'A%' ILIKE 'a!%' ESCAPE '!';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'Ab' ILIKE 'a!%' ESCAPE '!';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'A_' ILIKE 'a!_' ESCAPE '!';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'Ab' ILIKE 'a!_' ESCAPE '!';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'a!' ILIKE 'A!!' ESCAPE '!';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'A%' ILIKE 'ax%' ESCAPE 'x';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'Ab' ILIKE 'ax%' ESCAPE 'x';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'x' ILIKE 'xx' ESCAPE 'x';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'X' ILIKE 'xx' ESCAPE 'x';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'xy' ILIKE 'X%' ESCAPE 'x';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'x' ILIKE 'X' ESCAPE 'x';
-- COL1: TRUE

/* extensions V302-01 */
VALUES '%' ILIKE 'X%' ESCAPE 'x';
-- COL1: FALSE

/* extensions V302-01 */
VALUES '%' ILIKE 'ß%' ESCAPE 'ß';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ss' ILIKE 'ß%' ESCAPE 'ß';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'ß' ILIKE 'ßß' ESCAPE 'ß';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'SS' ILIKE 'ßß' ESCAPE 'ß';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'ß' ILIKE 'SS' ESCAPE 'ß';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'a%' NOT ILIKE 'A!%' ESCAPE '!';
-- COL1: FALSE

/* extensions V302-01 */
VALUES 'ab' NOT ILIKE 'A!%' ESCAPE '!';
-- COL1: TRUE

-- # The same escape errors as LIKE: an escape character that isn't followed
-- # by itself, % or _ is 22025 (8.5, General Rules, 3.b.i.2), and one that
-- # isn't one character long is 22019 (8.5, General Rules, 3.b.i.1).
/* extensions V302-01 */
VALUES 'a' ILIKE 'x' ESCAPE 'x';
-- error 22025: invalid escape sequence

/* extensions V302-01 */
VALUES 'a' ILIKE 'ß' ESCAPE 'ß';
-- error 22025: invalid escape sequence

/* extensions V302-01 */
VALUES 'a' ILIKE 'a' ESCAPE 'ab';
-- error 22019: invalid escape character

/* extensions V302-01 */
VALUES 'a' ILIKE 'a' ESCAPE '';
-- error 22019: invalid escape character

-- # Every operand has to be a character string (8.5, Syntax Rules, 1).
/* extensions V302-01 */
VALUES 1 ILIKE 'a';
-- error 42883: operator does not exist: SMALLINT ILIKE CHARACTER

/* extensions V302-01 */
VALUES 'a' NOT ILIKE 1;
-- error 42883: operator does not exist: CHARACTER ILIKE SMALLINT

/* extensions V302-01 */
VALUES 'a' ILIKE 'a' ESCAPE 1;
-- error 42883: operator does not exist: CHARACTER ILIKE SMALLINT

-- # The flagger: ILIKE needs the same features as the same LIKE, and V302-01.
/* flags */
VALUES 'a' LIKE 'a';
-- flags: F281, F641, F661
-- COL1: TRUE

/* extensions V302-01 */
/* flags */
VALUES 'a' ILIKE 'A';
-- flags: F281, F641, F661, V302-01
-- COL1: TRUE

/* extensions V302-01 */
/* flags */
VALUES 'a' NOT ILIKE 'A' ESCAPE '!';
-- flags: F281, F641, F661, V302-01
-- COL1: FALSE

/* flags */
SELECT x FROM t WHERE x LIKE 'Ab';
-- flags:
-- X: Ab

/* extensions V302-01 */
/* flags */
SELECT x FROM t WHERE x ILIKE 'AB';
-- flags: V302-01
-- X: Ab

/* extensions V302-01 */
/* flags */
SELECT x FROM t WHERE x || 'c' ILIKE 'abC';
-- flags: F281, V302-01
-- X: Ab

/* extensions V302-01 */
/* flags */
SELECT x FROM t WHERE x ILIKE y;
-- flags: F281, V302-01
-- X: Ab

/* extensions V302-01 */
/* flags */
SELECT x FROM t WHERE x NOT ILIKE y;
-- flags: F281, V302-01

/* extensions V302-01 */
/* flags */
SELECT x FROM t WHERE x ILIKE 'a' ESCAPE y;
-- flags: F281, V302-01
-- error 22019: invalid escape character

/* extensions V302-01 */
/* flags */
SELECT x FROM t WHERE x NOT ILIKE 'a' ESCAPE y;
-- flags: F281, V302-01
-- error 22019: invalid escape character

-- # Either side can be any expression that returns a character string,
-- # including one that starts with a reserved word, such as UPPER or CASE.
/* extensions V302-01 */
SELECT x FROM t WHERE (x) ILIKE (y);
-- X: Ab

/* extensions V302-01 */
SELECT x FROM t WHERE UPPER(x) ILIKE LOWER(y);
-- X: Ab

/* extensions V302-01 */
SELECT x FROM t WHERE x ILIKE CAST(y AS VARCHAR(5));
-- X: Ab

/* extensions V302-01 */
SELECT x FROM t WHERE x ILIKE CASE WHEN TRUE THEN 'AB' END;
-- X: Ab

/* extensions V302-01 */
SELECT x FROM t WHERE x ILIKE COALESCE(y, 'c');
-- X: Ab

-- # A pattern can't start with NULL, so ILIKE isn't the operator there, and
-- # as a name it's a syntax error. LIKE NULL is a syntax error for another
-- # reason: NULL on its own isn't a value.
SELECT x FROM t WHERE x ILIKE NULL;
-- error 42601: syntax error: unexpected ILIKE at line 1, column 25 near "t WHERE x ILIKE NULL"

SELECT x FROM t WHERE x LIKE NULL;
-- error 42601: syntax error: unexpected $end at line 1, column 34 near "WHERE x LIKE NULL", expecting "::"

-- # More functions that return a character string.
/* extensions V302-01 */
SELECT x FROM t WHERE x ILIKE TRIM(y);
-- X: Ab

/* extensions V302-01 */
SELECT x FROM t WHERE x ILIKE SUBSTRING(y FROM 1);
-- X: Ab

/* extensions V302-01 */
SELECT x FROM t WHERE x ILIKE NULLIF(y, 'c');
-- X: Ab

-- # TRUE can be on the left, but it isn't a character string.
/* extensions V302-01 */
VALUES TRUE ILIKE 'a';
-- error 42883: operator does not exist: BOOLEAN ILIKE CHARACTER

-- # An aggregate, a CASE and CURRENT_SCHEMA can be operands too.
/* extensions V302-01 */
SELECT x ILIKE MAX(y) FROM t GROUP BY x;
-- COL1: TRUE

/* extensions V302-01 */
SELECT x FROM t WHERE CASE WHEN TRUE THEN x END ILIKE 'AB';
-- X: Ab

/* extensions V302-01 */
VALUES CURRENT_SCHEMA ILIKE 'PUBLIC';
-- COL1: TRUE

/* extensions V302-01 */
VALUES 'public' ILIKE CURRENT_SCHEMA;
-- COL1: TRUE

-- # A parameter can be either operand.
/* extensions V302-01 */
/* params 'A' 'a' */
VALUES ? ILIKE ?;
-- sql: VALUES 'A' ILIKE 'a'
-- COL1: TRUE

/* extensions V302-01 */
/* params 'a' */
SELECT x FROM t WHERE x NOT ILIKE ?;
-- sql: SELECT x FROM t WHERE x NOT ILIKE 'a'
-- X: Ab

-- # A CHECK constraint keeps the text of its condition.
/* extensions V302-01 */
CREATE TABLE c (x VARCHAR(10) CONSTRAINT k CHECK (x ILIKE 'a%'));
INSERT INTO c (x) VALUES ('ABC');
INSERT INTO c (x) VALUES ('B');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 23514: violates check constraint: CHECK (X ILIKE 'a%') on ":memory:".PUBLIC.C

-- # A pattern can't start with TRUE either, so it isn't ILIKE, while LIKE TRUE
-- # parses and is an error because TRUE isn't a character string.
SELECT x FROM t WHERE x ILIKE TRUE;
-- error 42601: syntax error: unexpected ILIKE at line 1, column 25 near "t WHERE x ILIKE TRUE"

SELECT x FROM t WHERE x LIKE TRUE;
-- error 42883: operator does not exist: CHARACTER VARYING LIKE BOOLEAN
