-- # The default of a binary string column is a binary string literal that
-- # isn't longer than the column (Syntax Rule 4.a.ii). A BINARY default is
-- # padded with X'00' to the length of the column, and a BINARY VARYING
-- # default is the literal (General Rules 2.a.iv and 2.a.v).
/* types */
CREATE TABLE t (a INT, b BINARY(3) DEFAULT X'01', v VARBINARY(3) DEFAULT X'0203');
INSERT INTO t (a) VALUES (1);
SELECT b, v FROM t;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- B: 010000 (BINARY(3)) V: 0203 (BINARY VARYING(3))

CREATE TABLE t (b BINARY(1) DEFAULT X'0102');
-- error 42601: syntax error: DEFAULT X'0102' is not valid for column B BINARY(1)

CREATE TABLE t (b BINARY(2) DEFAULT 'ab');
-- error 42601: syntax error: DEFAULT 'ab' is not valid for column B BINARY(2)

CREATE TABLE t (v VARBINARY(2) DEFAULT 1);
-- error 42601: syntax error: DEFAULT 1 is not valid for column V BINARY VARYING(2)
