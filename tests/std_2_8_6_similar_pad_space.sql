-- # SIMILAR TO compares with the collation of its operands (General Rules, 8),
-- # which is PAD SPACE, like =. So the value can have more or fewer trailing
-- # spaces than the pattern needs.
VALUES 'a ' = 'a';
-- COL1: TRUE

VALUES 'a ' SIMILAR TO 'a';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a ';
-- COL1: TRUE

VALUES 'a     ' SIMILAR TO 'a  ';
-- COL1: TRUE

VALUES 'a  ' SIMILAR TO 'a     ';
-- COL1: TRUE

VALUES '   ' SIMILAR TO '';
-- COL1: TRUE

VALUES '' SIMILAR TO '   ';
-- COL1: TRUE

VALUES 'é ' SIMILAR TO 'é';
-- COL1: TRUE

-- # The spaces that pad a CHARACTER value to its length are trailing spaces
-- # too.
VALUES CAST('a' AS CHARACTER(3)) SIMILAR TO 'a';
-- COL1: TRUE

VALUES CAST('a' AS CHARACTER(3)) SIMILAR TO 'a ';
-- COL1: TRUE

VALUES CAST('a  ' AS CHARACTER VARYING(3)) SIMILAR TO 'a';
-- COL1: TRUE

CREATE TABLE t1 (c CHARACTER(5), v CHARACTER VARYING(5));
INSERT INTO t1 (c, v) VALUES ('a', 'a  ');
SELECT c SIMILAR TO 'a', v SIMILAR TO 'a', c = v FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: TRUE COL2: TRUE COL3: TRUE

-- # The spaces are only ignored at the end.
VALUES ' a' SIMILAR TO 'a';
-- COL1: FALSE

VALUES 'a' SIMILAR TO ' a';
-- COL1: FALSE

VALUES 'a b' SIMILAR TO 'ab';
-- COL1: FALSE

VALUES 'ab' SIMILAR TO 'a b';
-- COL1: FALSE

VALUES 'a b ' SIMILAR TO 'a b';
-- COL1: TRUE

VALUES 'b ' SIMILAR TO 'a';
-- COL1: FALSE

VALUES 'a ' SIMILAR TO 'b';
-- COL1: FALSE

-- # Only a space is padded, not other white space (a no-break space here).
VALUES 'a ' SIMILAR TO 'a';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a ';
-- COL1: FALSE

-- # A pattern can match more trailing spaces than the value has.
VALUES 'a' SIMILAR TO 'a *';
-- COL1: TRUE

VALUES 'a   ' SIMILAR TO 'a *';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a +';
-- COL1: TRUE

VALUES 'a   ' SIMILAR TO 'a +';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a ?';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a {3}';
-- COL1: TRUE

VALUES 'a ' SIMILAR TO 'a {3}';
-- COL1: TRUE

VALUES 'a     ' SIMILAR TO 'a {3}';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a {2,4}';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a {2,}';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a(  )+';
-- COL1: TRUE

VALUES 'a ' SIMILAR TO 'a(  ){2}';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a {999999999}';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a( |x){999999999}';
-- COL1: TRUE

VALUES 'a' SIMILAR TO '(a )+';
-- COL1: TRUE

VALUES 'a a ' SIMILAR TO '(a )+';
-- COL1: TRUE

VALUES 'a a' SIMILAR TO '(a )+';
-- COL1: TRUE

VALUES 'a a b' SIMILAR TO '(a )+';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'b|a ';
-- COL1: TRUE

VALUES '' SIMILAR TO '( )|a';
-- COL1: TRUE

-- # Nothing else in the pattern can be required after the spaces.
VALUES 'a' SIMILAR TO 'a +b';
-- COL1: FALSE

VALUES 'a ' SIMILAR TO 'a b';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a b*';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a b?';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a b+';
-- COL1: FALSE

-- # A space is one of the strings of "_", "%" and some character sets.
VALUES 'a' SIMILAR TO 'a_';
-- COL1: TRUE

VALUES '' SIMILAR TO '_';
-- COL1: TRUE

VALUES 'a' SIMILAR TO '_a';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a__';
-- COL1: TRUE

VALUES 'a ' SIMILAR TO 'a%';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a%b';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a[ x]';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a[x]';
-- COL1: FALSE

VALUES 'a ' SIMILAR TO 'a[x]';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a[^x]';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a[^ ]';
-- COL1: FALSE

VALUES 'a ' SIMILAR TO 'a[^ ]';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a[ x^ ]';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a[[:SPACE:]]';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a[[:WHITESPACE:]]+';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a[[:ALPHA:]]';
-- COL1: FALSE

-- # NOT SIMILAR TO is the opposite.
VALUES 'a ' NOT SIMILAR TO 'a';
-- COL1: FALSE

VALUES 'a' NOT SIMILAR TO 'a ';
-- COL1: FALSE

VALUES CAST('a' AS CHARACTER(3)) NOT SIMILAR TO 'a';
-- COL1: FALSE

VALUES 'a' NOT SIMILAR TO 'a {3}';
-- COL1: FALSE

VALUES 'a' NOT SIMILAR TO 'a_';
-- COL1: FALSE

VALUES ' a' NOT SIMILAR TO 'a';
-- COL1: TRUE

VALUES 'a' NOT SIMILAR TO 'a +b';
-- COL1: TRUE

VALUES 'a ' NOT SIMILAR TO 'a[^ ]';
-- COL1: TRUE

-- # With an escape character.
VALUES 'a% ' SIMILAR TO 'a!%' ESCAPE '!';
-- COL1: TRUE

VALUES 'a ' SIMILAR TO 'a!%' ESCAPE '!';
-- COL1: FALSE

VALUES 'a' SIMILAR TO 'a  ' ESCAPE ' ';
-- COL1: TRUE

VALUES 'a' SIMILAR TO 'a!_' ESCAPE '!';
-- COL1: FALSE

-- # A LIKE has NO PAD, so these are different.
VALUES 'a ' LIKE 'a';
-- COL1: FALSE

VALUES 'a' LIKE 'a ';
-- COL1: FALSE

VALUES CAST('a' AS CHARACTER(3)) LIKE 'a';
-- COL1: FALSE

VALUES 'a' LIKE 'a_';
-- COL1: FALSE

VALUES 'a ' NOT LIKE 'a';
-- COL1: TRUE
