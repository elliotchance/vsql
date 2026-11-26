-- # A binary string column can only get a binary string type that's at least
-- # as long (Syntax Rule 15.b, #1726). A BINARY value is padded with X'00' to
-- # the new length, and a BINARY VARYING value keeps its length.
/* types */
CREATE TABLE t (b BINARY(2), v VARBINARY(4));
INSERT INTO t (b, v) VALUES (X'0102', X'0A');
ALTER TABLE t ALTER COLUMN b SET DATA TYPE BINARY(3);
ALTER TABLE t ALTER COLUMN v SET DATA TYPE VARBINARY(6);
SELECT b, v FROM t;
ALTER TABLE t ALTER COLUMN b SET DATA TYPE VARBINARY(3);
ALTER TABLE t ALTER COLUMN v SET DATA TYPE BINARY(6);
SELECT b, v FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- B: 010200 (BINARY(3)) V: 0A (BINARY VARYING(6))
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- B: 010200 (BINARY VARYING(3)) V: 0A0000000000 (BINARY(6))

-- # The same length is also allowed.
/* types */
CREATE TABLE t (b BINARY(2), v VARBINARY(4));
INSERT INTO t (b, v) VALUES (X'0102', X'0A');
ALTER TABLE t ALTER COLUMN b SET DATA TYPE VARBINARY(2);
ALTER TABLE t ALTER COLUMN v SET DATA TYPE BINARY(4);
SELECT b, v FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: ALTER TABLE 1
-- msg: ALTER TABLE 1
-- B: 0102 (BINARY VARYING(2)) V: 0A000000 (BINARY(4))

-- # A shorter binary string, or another type, is an error.
CREATE TABLE t (b BINARY(2), v VARBINARY(4), c VARCHAR(4));
ALTER TABLE t ALTER COLUMN v SET DATA TYPE VARBINARY(2);
ALTER TABLE t ALTER COLUMN v SET DATA TYPE BINARY(3);
ALTER TABLE t ALTER COLUMN b SET DATA TYPE BINARY(1);
ALTER TABLE t ALTER COLUMN b SET DATA TYPE VARCHAR(2);
ALTER TABLE t ALTER COLUMN b SET DATA TYPE BLOB(2);
ALTER TABLE t ALTER COLUMN c SET DATA TYPE VARBINARY(4);
ALTER TABLE t ALTER COLUMN c SET DATA TYPE VARCHAR(2);
-- msg: CREATE TABLE 1
-- error 42601: syntax error: cannot change the data type of column V from BINARY VARYING(4) to BINARY VARYING(2)
-- error 42601: syntax error: cannot change the data type of column V from BINARY VARYING(4) to BINARY(3)
-- error 42601: syntax error: cannot change the data type of column B from BINARY(2) to BINARY(1)
-- error 42601: syntax error: cannot change the data type of column B from BINARY(2) to CHARACTER VARYING(2)
-- error 42601: syntax error: cannot change the data type of column B from BINARY(2) to BINARY LARGE OBJECT(2)
-- error 42601: syntax error: cannot change the data type of column C from CHARACTER VARYING(4) to BINARY VARYING(4)
-- error 42601: syntax error: cannot change the data type of column C from CHARACTER VARYING(4) to CHARACTER VARYING(2)
