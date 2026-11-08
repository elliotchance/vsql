-- # ESCAPE is kept when it's shown.
/* extensions V001-01 */
EXPLAIN VALUES 'a%' SIMILAR TO 'a!%' ESCAPE '!';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a%' SIMILAR TO 'a!%' ESCAPE '!')

/* extensions V001-01 */
EXPLAIN VALUES 'a%' NOT SIMILAR TO 'a!%' ESCAPE '!';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a%' NOT SIMILAR TO 'a!%' ESCAPE '!')

-- # The escape character makes the next special character match only itself.
VALUES 'a%' SIMILAR TO 'a!%' ESCAPE '!';
-- COL1: TRUE

VALUES 'ab' SIMILAR TO 'a!%' ESCAPE '!';
-- COL1: FALSE

VALUES 'a%' NOT SIMILAR TO 'a!%' ESCAPE '!';
-- COL1: FALSE

VALUES 'ab' NOT SIMILAR TO 'a!%' ESCAPE '!';
-- COL1: TRUE

VALUES 'abc' SIMILAR TO 'a%' ESCAPE '!';
-- COL1: TRUE

-- # Each special character escaped, which then doesn't have its usual meaning.
VALUES ROW('a_' SIMILAR TO 'a!_' ESCAPE '!', 'ab' SIMILAR TO 'a!_' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('a*' SIMILAR TO 'a!*' ESCAPE '!', 'aa' SIMILAR TO 'a!*' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('a+' SIMILAR TO 'a!+' ESCAPE '!', 'aa' SIMILAR TO 'a!+' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('a?' SIMILAR TO 'a!?' ESCAPE '!', 'a' SIMILAR TO 'a!?' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('a{2}' SIMILAR TO 'a!{2}' ESCAPE '!', 'aa' SIMILAR TO 'a!{2}' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('a|b' SIMILAR TO 'a!|b' ESCAPE '!', 'a' SIMILAR TO 'a!|b' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('(a)' SIMILAR TO '!(a!)' ESCAPE '!', 'a' SIMILAR TO '!(a!)' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('[a]' SIMILAR TO '![a!]' ESCAPE '!', 'a' SIMILAR TO '![a!]' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES '^-' SIMILAR TO '!^!-' ESCAPE '!';
-- COL1: TRUE

VALUES ROW('a!' SIMILAR TO 'a!!' ESCAPE '!', 'a!!' SIMILAR TO 'a!!' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

-- # An escaped character can be repeated or grouped like any other. The escape
-- # character is one character, not one byte.
VALUES 'a***' SIMILAR TO 'a!*+' ESCAPE '!';
-- COL1: TRUE

VALUES 'a(b)(b)' SIMILAR TO 'a(!(b!))+' ESCAPE '!';
-- COL1: TRUE

VALUES 'a%b%' SIMILAR TO '(a|b)!%(a|b)!%' ESCAPE '!';
-- COL1: TRUE

VALUES ROW('é*' SIMILAR TO 'ééé*' ESCAPE 'é', 'éé' SIMILAR TO 'éé*' ESCAPE 'é');
-- COL1: TRUE COL2: TRUE

-- # In a character set, an escaped -, ] or ^ is that character, so it isn't a
-- # range, the end of the set or a negation.
VALUES ROW('-' SIMILAR TO '[a!-z]' ESCAPE '!', 'b' SIMILAR TO '[a!-z]' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW(']' SIMILAR TO '[!]]' ESCAPE '!', '^' SIMILAR TO '[!^a]' ESCAPE '!');
-- COL1: TRUE COL2: TRUE

VALUES ROW('^' SIMILAR TO '[a!^]' ESCAPE '!', 'b' SIMILAR TO '[a!^]' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('+' SIMILAR TO '[!*-!-]' ESCAPE '!', 'a' SIMILAR TO '[!*-!-]' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('x' SIMILAR TO '[^!^]' ESCAPE '!', '^' SIMILAR TO '[^!^]' ESCAPE '!');
-- COL1: TRUE COL2: FALSE

VALUES ROW('b' SIMILAR TO '[a-z^!^b]' ESCAPE '!', '^' SIMILAR TO '[!^a-z^b]' ESCAPE '!');
-- COL1: FALSE COL2: TRUE

-- # A character class still works with an escape character other than :.
VALUES 'a' SIMILAR TO '[[:ALPHA:]]' ESCAPE '!';
-- COL1: TRUE

-- # Escaping a character that isn't special, or ending with the escape
-- # character, isn't a valid pattern. Neither is escaping part of a repeat
-- # factor, except its opening brace.
VALUES 'a!b' SIMILAR TO 'a!b' ESCAPE '!';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a!' ESCAPE '!';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO '[!a]' ESCAPE '!';
-- error 2201B: invalid regular expression

VALUES 'aa' SIMILAR TO 'a{!2}' ESCAPE '!';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a{1!,2}' ESCAPE '!';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO 'a!{1}' ESCAPE '!';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a{1,!}' ESCAPE '!';
-- error 2201B: invalid regular expression

-- # A digit can be the escape character, but then a repeat factor can't
-- # contain it.
VALUES ROW('a1' SIMILAR TO 'a11' ESCAPE '1', 'aa' SIMILAR TO 'a{2}' ESCAPE '1');
-- COL1: TRUE COL2: TRUE

VALUES 'aa' SIMILAR TO 'a{11}' ESCAPE '1';
-- error 2201B: invalid regular expression

-- # A special character can be the escape character, but then it can't be used
-- # with its special meaning (General Rules, 3.b).
VALUES ROW('%' SIMILAR TO '%%' ESCAPE '%', 'a%b' SIMILAR TO 'a%%b' ESCAPE '%');
-- COL1: TRUE COL2: TRUE

VALUES ROW('a_' SIMILAR TO 'a%_' ESCAPE '%', '(' SIMILAR TO '((' ESCAPE '(');
-- COL1: TRUE COL2: TRUE

VALUES 'abc' SIMILAR TO 'a%' ESCAPE '%';
-- error 2200C: invalid use of escape character

VALUES 'a' SIMILAR TO '(a)' ESCAPE '(';
-- error 2200C: invalid use of escape character

VALUES 'ab' SIMILAR TO '[ab]' ESCAPE ']';
-- error 2200C: invalid use of escape character

-- # An invalid pattern is still invalid when the escape character is special.
VALUES 'a' SIMILAR TO '(' ESCAPE '[';
-- error 2201B: invalid regular expression

-- # : can be the escape character, but not with a character class (General
-- # Rules, 3.c), which is checked before the rest of the pattern.
VALUES ROW(':' SIMILAR TO '::' ESCAPE ':', 'a%' SIMILAR TO 'a:%' ESCAPE ':');
-- COL1: TRUE COL2: TRUE

VALUES ':' SIMILAR TO ':' ESCAPE ':';
-- error 2201B: invalid regular expression

VALUES 'a' SIMILAR TO '[[:ALPHA:]]' ESCAPE ':';
-- error 2200B: escape character conflict

VALUES 'a' SIMILAR TO 'x|[^[:DIGIT:]]' ESCAPE ':';
-- error 2200B: escape character conflict

VALUES 'a' SIMILAR TO '([[:ALPHA:]]' ESCAPE ':';
-- error 2201B: invalid regular expression

-- # The escape character must be exactly one character (General Rules, 3.a).
VALUES 'a' SIMILAR TO 'a' ESCAPE '';
-- error 22019: invalid escape character

VALUES 'a' SIMILAR TO 'a' ESCAPE '!!';
-- error 22019: invalid escape character

-- # Any NULL operand makes the result UNKNOWN (General Rules, 4.b). When the
-- # escape character is NULL, the pattern can't be checked, because what's
-- # valid depends on the escape character.
VALUES CAST(NULL AS VARCHAR(10)) SIMILAR TO 'a' ESCAPE '!';
-- COL1: UNKNOWN

VALUES 'a' SIMILAR TO CAST(NULL AS VARCHAR(10)) ESCAPE '!';
-- COL1: UNKNOWN

VALUES 'a' SIMILAR TO 'a' ESCAPE CAST(NULL AS VARCHAR(10));
-- COL1: UNKNOWN

VALUES 'a' NOT SIMILAR TO 'a' ESCAPE CAST(NULL AS VARCHAR(10));
-- COL1: UNKNOWN

VALUES 'a' SIMILAR TO '(' ESCAPE CAST(NULL AS VARCHAR(10));
-- COL1: UNKNOWN

-- # The pattern and the escape character are checked before a NULL operand
-- # makes the result UNKNOWN (General Rules, 2 and 3 come before 4), so they're
-- # still an error with a NULL value or pattern (#1092).
VALUES CAST(NULL AS VARCHAR(10)) SIMILAR TO '(';
-- error 2201B: invalid regular expression

VALUES CAST(NULL AS VARCHAR(10)) SIMILAR TO 'a' ESCAPE '!!';
-- error 22019: invalid escape character

VALUES 'a' SIMILAR TO CAST(NULL AS VARCHAR(10)) ESCAPE '!!';
-- error 22019: invalid escape character

VALUES CAST(NULL AS VARCHAR(10)) SIMILAR TO 'a%' ESCAPE '%';
-- error 2200C: invalid use of escape character

VALUES CAST(NULL AS VARCHAR(10)) NOT SIMILAR TO '[[:ALPHA:]]' ESCAPE ':';
-- error 2200B: escape character conflict

-- # The pattern and the escape character can be expressions or columns, so
-- # they can be different for each row.
VALUES 'a%' SIMILAR TO 'a#%' ESCAPE TRIM(' # ');
-- COL1: TRUE

CREATE TABLE t1 (x VARCHAR(10), e CHAR(1));
INSERT INTO t1 (x, e) VALUES ('1+2', '!');
INSERT INTO t1 (x, e) VALUES ('12', '!');
INSERT INTO t1 (x, e) VALUES ('3+4', '#');
SELECT x FROM t1 WHERE x SIMILAR TO '[0-9]' || e || '+[0-9]' ESCAPE e;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 1+2
-- X: 3+4
