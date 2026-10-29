SET TRANSACTION;
-- msg: SET TRANSACTION

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
-- error 42601: syntax error: unexpected LOCAL

START TRANSACTION;
SET TRANSACTION DIAGNOSTICS SIZE 1;
-- msg: START TRANSACTION
-- error 25001: invalid transaction state: active sql transaction
