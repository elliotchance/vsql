/* connection 1 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
/* connection 2 */
INSERT INTO foo (bar) VALUES (456);
SELECT * FROM foo;
-- 1: msg: CREATE TABLE 1
-- 1: msg: INSERT 1
-- 2: msg: INSERT 1
-- 2: BAR: 123
-- 2: BAR: 456

/* connection 1 */
/* connection 2 */
CREATE TABLE foo (bar INT);
INSERT INTO foo (bar) VALUES (123);
/* connection 1 */
INSERT INTO foo (bar) VALUES (456);
SELECT * FROM foo;
-- 2: msg: CREATE TABLE 1
-- 2: msg: INSERT 1
-- 1: msg: INSERT 1
-- 1: BAR: 123
-- 1: BAR: 456

-- # F771 Connection management: a connection statement can only be run by an
-- # Agent, but it's flagged when it's prepared.
/* flags */
CONNECT TO ':memory:';
CONNECT TO DEFAULT;
CONNECT TO ':memory:' AS 'c';
SET CONNECTION DEFAULT;
SET CONNECTION 'c';
DISCONNECT DEFAULT;
DISCONNECT 'c';
DISCONNECT ALL;
DISCONNECT CURRENT;
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
-- flags: F771
-- error 42601: syntax error: a connection statement can only be used in direct SQL
