-- # The value of a character string literal is normalized to NFC, because the
-- # character repertoire is UCS (General Rules, 2).

VALUES U&'\0065\0301' = U&'\00E9';
-- COL1: TRUE

VALUES CHAR_LENGTH(U&'\0065\0301');
-- COL1: 1

VALUES CHAR_LENGTH(U&'\00E9');
-- COL1: 1

VALUES U&'\0065\0301' <> U&'\00E9';
-- COL1: FALSE

-- # The characters don't need to be escapes, and the type counts the characters
-- # that are left.

/* types */
VALUES 'e<U+0301>';
-- COL1: é (CHARACTER(1))

VALUES 'e<U+0301>' = 'é';
-- COL1: TRUE

VALUES U&'e!0301' UESCAPE '!' = U&'\00E9';
-- COL1: TRUE

-- # A compound literal is normalized after it's put together.

VALUES CHAR_LENGTH('e'
'<U+0301>');
-- COL1: 1

-- # Text that's already NFC stays the same.

VALUES 'plain';
-- COL1: plain

VALUES 'é';
-- COL1: é

VALUES 'ぁ';
-- COL1: ぁ

-- # A character can decompose to a single other one, or more than one level.

VALUES U&'\212B' = U&'\00C5', U&'\2126' = U&'\03A9';
-- COL1: TRUE
-- COL1: TRUE

VALUES U&'\1E61\0323' = U&'\1E69', U&'\0073\0323\0307' = U&'\1E69';
-- COL1: TRUE
-- COL1: TRUE

-- # Some characters are never composed, so they always stay as two.

VALUES CHAR_LENGTH(U&'\0958');
-- COL1: 2

VALUES U&'\0958' = U&'\0915\093C';
-- COL1: TRUE

VALUES CHAR_LENGTH(U&'\+01D15E');
-- COL1: 2

-- # Combining marks are put in order of their combining classes.

VALUES U&'\0061\0301\0323' = U&'\0061\0323\0301', U&'\0061\0301\0323' = U&'\1EA1\0301';
-- COL1: TRUE
-- COL1: TRUE

VALUES CHAR_LENGTH(U&'\0061\0301\0323');
-- COL1: 2

-- # Marks of the same class stay in the same order.

VALUES U&'\0061\0301\0300' = U&'\0061\0300\0301';
-- COL1: FALSE

-- # A mark is blocked by a mark of the same class, but not of a lower one.

VALUES CHAR_LENGTH(U&'\0061\0300\0301');
-- COL1: 2

VALUES U&'\0061\0323\0300' = U&'\1EA1\0300';
-- COL1: TRUE

-- # A mark can't combine across another starter, or when there is no starter.

VALUES CHAR_LENGTH(U&'\0061\0062\0301');
-- COL1: 3

VALUES CHAR_LENGTH(U&'\0301\0065');
-- COL1: 2

-- # Two starters can combine.

VALUES U&'\09C7\09BE' = U&'\09CB';
-- COL1: TRUE

-- # Hangul is calculated rather than found in a table.

VALUES U&'\1100\1161' = U&'\AC00', U&'\1100\1161\11A8' = U&'\AC01', U&'\AC00\11A8' = U&'\AC01';
-- COL1: TRUE
-- COL1: TRUE
-- COL1: TRUE

VALUES CHAR_LENGTH(U&'\AC01'), CHAR_LENGTH(U&'\AC00'), CHAR_LENGTH(U&'\AC01\11A8');
-- COL1: 1
-- COL1: 1
-- COL1: 2

VALUES CHAR_LENGTH(U&'\1100\0041'), CHAR_LENGTH(U&'\AC00\0041'), CHAR_LENGTH(U&'\AC00\11A7');
-- COL1: 2
-- COL1: 2
-- COL1: 2

-- # The normalized value is what's stored and compared.

CREATE TABLE t (x VARCHAR(1) PRIMARY KEY);
INSERT INTO t (x) VALUES (U&'\0065\0301');
SELECT CHAR_LENGTH(x) FROM t;
SELECT COUNT(*) FROM t WHERE x = U&'\00E9';
INSERT INTO t (x) VALUES (U&'\00E9');
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- COL1: 1
-- COL1: 1
-- error 23505: violates unique constraint: PRIMARY KEY on ":memory:".PUBLIC.T
