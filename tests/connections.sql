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
