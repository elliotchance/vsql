-- # ESCAPE is kept when it's shown.
/* extensions V001-01 */
EXPLAIN VALUES 'a%' LIKE 'a!%' ESCAPE '!';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a%' LIKE 'a!%' ESCAPE '!')

/* extensions V001-01 */
EXPLAIN VALUES 'a%' NOT LIKE 'a!%' ESCAPE '!';
-- EXPLAIN: VALUES (COL1 BOOLEAN) = ROW('a%' NOT LIKE 'a!%' ESCAPE '!')

-- # The escape character makes the next % or _ (or the escape character
-- # itself) match only that character.
VALUES 'a%' LIKE 'a!%' ESCAPE '!';
-- COL1: TRUE

VALUES 'ab' LIKE 'a!%' ESCAPE '!';
-- COL1: FALSE

VALUES 'a' LIKE 'a!%' ESCAPE '!';
-- COL1: FALSE

VALUES 'a%' NOT LIKE 'a!%' ESCAPE '!';
-- COL1: FALSE

VALUES 'ab' NOT LIKE 'a!%' ESCAPE '!';
-- COL1: TRUE

VALUES 'a_' LIKE 'a!_' ESCAPE '!';
-- COL1: TRUE

VALUES 'ab' LIKE 'a!_' ESCAPE '!';
-- COL1: FALSE

VALUES 'a!' LIKE 'a!!' ESCAPE '!';
-- COL1: TRUE

VALUES 'a!!' LIKE 'a!!' ESCAPE '!';
-- COL1: FALSE

-- # Escaped characters next to wildcards.
VALUES '100%' LIKE '%!%' ESCAPE '!';
-- COL1: TRUE

VALUES '100' LIKE '%!%' ESCAPE '!';
-- COL1: FALSE

VALUES '50% off' LIKE '%!%%' ESCAPE '!';
-- COL1: TRUE

VALUES '50 off' LIKE '%!%%' ESCAPE '!';
-- COL1: FALSE

VALUES 'ab_xc' LIKE '%!__c' ESCAPE '!';
-- COL1: TRUE

VALUES 'a_b_c' LIKE '%!__c' ESCAPE '!';
-- COL1: FALSE

-- # Any character can be the escape character, even a wildcard, which then
-- # isn't a wildcard on its own. It's one character, not one byte.
VALUES 'a%b' LIKE 'a\%b' ESCAPE '\';
-- COL1: TRUE

VALUES 'a%b' LIKE 'a%%b' ESCAPE '%';
-- COL1: TRUE

VALUES 'axb' LIKE 'a%%b' ESCAPE '%';
-- COL1: FALSE

VALUES 'axb' LIKE 'a_b' ESCAPE '%';
-- COL1: TRUE

VALUES 'a_b' LIKE 'a__b' ESCAPE '_';
-- COL1: TRUE

VALUES 'axb' LIKE 'a__b' ESCAPE '_';
-- COL1: FALSE

VALUES 'é%' LIKE 'éé%' ESCAPE 'é';
-- COL1: TRUE

-- # A pattern doesn't have to use the escape character.
VALUES 'abc' LIKE 'a%' ESCAPE '!';
-- COL1: TRUE

-- # The escape character can only be followed by %, _ or itself, and not be
-- # last (General Rules, 3.b.i.2).
VALUES 'abc' LIKE 'abc' ESCAPE 'b';
-- error 22025: invalid escape sequence

VALUES 'a' LIKE 'a!' ESCAPE '!';
-- error 22025: invalid escape sequence

VALUES 'ab' LIKE 'a!b' ESCAPE '!';
-- error 22025: invalid escape sequence

VALUES 'ab' NOT LIKE '!' ESCAPE '!';
-- error 22025: invalid escape sequence

-- # The escape character must be exactly one character (General Rules,
-- # 3.b.i.1).
VALUES 'a' LIKE 'a' ESCAPE '';
-- error 22019: invalid escape character

VALUES 'a' LIKE 'a' ESCAPE '!!';
-- error 22019: invalid escape character

-- # Any NULL operand makes the result UNKNOWN (General Rules, 3.a.ii). That's
-- # checked first, so a NULL with an invalid escape character isn't an error.
VALUES CAST(NULL AS VARCHAR(10)) LIKE 'a' ESCAPE '!';
-- COL1: UNKNOWN

VALUES 'a' LIKE CAST(NULL AS VARCHAR(10)) ESCAPE '!';
-- COL1: UNKNOWN

VALUES 'a' LIKE 'a' ESCAPE CAST(NULL AS VARCHAR(10));
-- COL1: UNKNOWN

VALUES 'a' NOT LIKE 'a' ESCAPE CAST(NULL AS VARCHAR(10));
-- COL1: UNKNOWN

VALUES CAST(NULL AS VARCHAR(10)) LIKE 'a' ESCAPE '!!';
-- COL1: UNKNOWN

VALUES 'a' LIKE 'a' ESCAPE CAST(NULL AS VARCHAR(10)) IS UNKNOWN;
-- COL1: TRUE

-- # The pattern and the escape character can be expressions or columns, so
-- # they can be different for each row.
VALUES 'a!%' LIKE 'a' || '!!' || '!%' ESCAPE '!';
-- COL1: TRUE

VALUES 'a%' LIKE 'a#%' ESCAPE TRIM(' # ');
-- COL1: TRUE

CREATE TABLE t1 (x VARCHAR(10), e CHAR(1));
INSERT INTO t1 (x, e) VALUES ('10%', '!');
INSERT INTO t1 (x, e) VALUES ('10', '!');
INSERT INTO t1 (x, e) VALUES ('5%', '#');
SELECT x FROM t1 WHERE x LIKE '%0!%' ESCAPE '!';
SELECT x FROM t1 WHERE x LIKE '%' || e || '%' ESCAPE e;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: INSERT 1
-- msg: INSERT 1
-- X: 10%
-- X: 10%
-- X: 5%

