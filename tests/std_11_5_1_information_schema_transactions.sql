-- # A table is only described to other transactions once it's committed.
/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (x INT);
SELECT table_name FROM information_schema.tables WHERE table_schema = 'PUBLIC';
/* connection 2 */
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'PUBLIC';
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: TABLE_NAME: FOO
-- 2: COL1: 0

/* connection 1 */
START TRANSACTION;
CREATE TABLE foo (x INT);
COMMIT;
/* connection 2 */
SELECT table_name FROM information_schema.tables WHERE table_schema = 'PUBLIC';
-- 1: msg: START TRANSACTION
-- 1: msg: CREATE TABLE 1
-- 1: msg: COMMIT
-- 2: TABLE_NAME: FOO

-- # A table that's rolled back or dropped isn't described, and neither are its
-- # columns.
START TRANSACTION;
CREATE TABLE foo (x INT);
ROLLBACK;
SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'PUBLIC';
-- msg: START TRANSACTION
-- msg: CREATE TABLE 1
-- msg: ROLLBACK
-- COL1: 0

CREATE TABLE foo (x INT);
DROP TABLE foo RESTRICT;
SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'PUBLIC';
-- msg: CREATE TABLE 1
-- msg: DROP TABLE 1
-- COL1: 0
