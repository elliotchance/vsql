-- # SET TRANSACTION doesn't need any characteristics. DIAGNOSTICS SIZE is
-- # flagged as F121 (17.3, Conformance Rules, 2), and START TRANSACTION as T241
-- # (17.1, Conformance Rules, 1).
SET TRANSACTION;
-- msg: SET TRANSACTION

/* flags */
SET TRANSACTION DIAGNOSTICS SIZE 1;
-- flags: F121
-- msg: SET TRANSACTION

/* flags */
START TRANSACTION DIAGNOSTICS SIZE 1;
-- flags: F121, T241
-- msg: START TRANSACTION

-- # DIAGNOSTICS SIZE is the most conditions kept for a statement, so only one
-- # of the two truncation warnings is shown. SET TRANSACTION is only for the
-- # next transaction (here the first VALUES, which is a transaction of its
-- # own), and then the default of 100 is used again (17.7, General Rules,
-- # 10.b.i). START TRANSACTION can set it for its own transaction, but without
-- # characteristics it uses the default rather than a SET TRANSACTION before it
-- # (17.1, General Rules, 2.a).
SET TRANSACTION DIAGNOSTICS SIZE 1;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
-- msg: SET TRANSACTION
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: abcabc

START TRANSACTION DIAGNOSTICS SIZE 1;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
COMMIT;
-- msg: START TRANSACTION
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- msg: COMMIT

SET TRANSACTION DIAGNOSTICS SIZE 1;
START TRANSACTION;
VALUES CAST('abcde' AS CHARACTER(3)) || CAST('abcde' AS CHARACTER(3));
COMMIT;
-- msg: SET TRANSACTION
-- msg: START TRANSACTION
-- warning 01004: string data, right truncation
-- warning 01004: string data, right truncation
-- COL1: abcabc
-- msg: COMMIT

-- # Less than 1 is 35000 (General Rules, 2 and 17.1, General Rules, 3). The
-- # size must be exact numeric with scale 0, so even 1.0 is 42804 (17.3, Syntax
-- # Rules, 6), and it can only be given once (17.3, Syntax Rules, 2). More than
-- # 100, the most that vsql allows, is a warning 01012 and 100 is used (General
-- # Rules, 3). SET TRANSACTION can't be explained, and LOCAL (T251) isn't
-- # supported.
SET TRANSACTION DIAGNOSTICS SIZE 0;
SET TRANSACTION DIAGNOSTICS SIZE -1;
START TRANSACTION DIAGNOSTICS SIZE 0;
SET TRANSACTION DIAGNOSTICS SIZE 1.5;
SET TRANSACTION DIAGNOSTICS SIZE 'a';
SET TRANSACTION DIAGNOSTICS SIZE 1, DIAGNOSTICS SIZE 2;
SET TRANSACTION DIAGNOSTICS SIZE 101;
SET TRANSACTION DIAGNOSTICS SIZE 1.0;
EXPLAIN SET TRANSACTION;
SET LOCAL TRANSACTION DIAGNOSTICS SIZE 1;
-- error 35000: invalid condition number
-- error 35000: invalid condition number
-- error 35000: invalid condition number
-- error 42804: data type mismatch for DIAGNOSTICS SIZE: expected exact numeric with scale 0 but got NUMERIC(2, 1)
-- error 42804: data type mismatch for DIAGNOSTICS SIZE: expected exact numeric with scale 0 but got CHARACTER(1)
-- error 42601: syntax error: DIAGNOSTICS SIZE can only be used once
-- warning 01012: invalid number of conditions
-- msg: SET TRANSACTION
-- error 42804: data type mismatch for DIAGNOSTICS SIZE: expected exact numeric with scale 0 but got NUMERIC(2, 1)
-- error 42601: syntax error: Cannot EXPLAIN SET TRANSACTION
-- error 42601: syntax error: unexpected LOCAL at line 1, column 5 near "SET LOCAL TRANSACTION"

-- # SET TRANSACTION isn't allowed in an active transaction (General Rules,
-- # 1.a.i).
START TRANSACTION;
SET TRANSACTION DIAGNOSTICS SIZE 1;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction
