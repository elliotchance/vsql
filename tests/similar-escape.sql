EXPLAIN VALUES 'a%' SIMILAR TO 'a!%' ESCAPE '!';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a%' SIMILAR TO 'a!%' ESCAPE '!')

EXPLAIN VALUES 'a%' NOT SIMILAR TO 'a!%' ESCAPE '!';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a%' NOT SIMILAR TO 'a!%' ESCAPE '!')

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

VALUES 'a***' SIMILAR TO 'a!*+' ESCAPE '!';
-- COL1: TRUE

VALUES 'a(b)(b)' SIMILAR TO 'a(!(b!))+' ESCAPE '!';
-- COL1: TRUE

VALUES 'a%b%' SIMILAR TO '(a|b)!%(a|b)!%' ESCAPE '!';
-- COL1: TRUE

VALUES ROW('é*' SIMILAR TO 'ééé*' ESCAPE 'é', 'éé' SIMILAR TO 'éé*' ESCAPE 'é');
-- COL1: TRUE COL2: TRUE

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

VALUES 'a' SIMILAR TO '[[:ALPHA:]]' ESCAPE '!';
-- COL1: TRUE

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

VALUES ROW('a1' SIMILAR TO 'a11' ESCAPE '1', 'aa' SIMILAR TO 'a{2}' ESCAPE '1');
-- COL1: TRUE COL2: TRUE

VALUES 'aa' SIMILAR TO 'a{11}' ESCAPE '1';
-- error 2201B: invalid regular expression

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

VALUES 'a' SIMILAR TO '(' ESCAPE '[';
-- error 2201B: invalid regular expression

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

VALUES 'a' SIMILAR TO 'a' ESCAPE '';
-- error 22019: invalid escape character

VALUES 'a' SIMILAR TO 'a' ESCAPE '!!';
-- error 22019: invalid escape character

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
