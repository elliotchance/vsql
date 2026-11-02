VALUES TRUE AND TRUE;
-- COL1: TRUE

VALUES TRUE AND FALSE;
-- COL1: FALSE

VALUES FALSE AND TRUE;
-- COL1: FALSE

VALUES FALSE AND FALSE;
-- COL1: FALSE

VALUES TRUE OR TRUE;
-- COL1: TRUE

VALUES TRUE OR FALSE;
-- COL1: TRUE

VALUES FALSE OR TRUE;
-- COL1: TRUE

VALUES FALSE OR FALSE;
-- COL1: FALSE

VALUES NOT TRUE;
-- COL1: FALSE

VALUES NOT FALSE;
-- COL1: TRUE

-- # The operands of a boolean operator must be booleans (#775).
VALUES NOT 'a';
VALUES NOT 5;
VALUES 1 AND TRUE;
VALUES TRUE AND 1;
VALUES 'a' OR FALSE;
VALUES FALSE OR 'a';
VALUES 1 IS TRUE;
VALUES 1 IS NOT UNKNOWN;
-- error 42804: data type mismatch in NOT: expected BOOLEAN but got CHARACTER(1)
-- error 42804: data type mismatch in NOT: expected BOOLEAN but got SMALLINT
-- error 42804: data type mismatch in AND: expected BOOLEAN but got SMALLINT
-- error 42804: data type mismatch in AND: expected BOOLEAN but got SMALLINT
-- error 42804: data type mismatch in OR: expected BOOLEAN but got CHARACTER(1)
-- error 42804: data type mismatch in OR: expected BOOLEAN but got CHARACTER(1)
-- error 42804: data type mismatch in IS: expected BOOLEAN but got SMALLINT
-- error 42804: data type mismatch in IS: expected BOOLEAN but got SMALLINT

CREATE TABLE t (x INTEGER);
INSERT INTO t (x) VALUES (1);
SELECT * FROM t WHERE x AND x;
SELECT * FROM t WHERE x > 0 AND x IS NOT NULL;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- error 42804: data type mismatch in AND: expected BOOLEAN but got INTEGER
-- X: 1
