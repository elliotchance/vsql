-- # A transaction includes every catalog, not just the current one.
/* create_catalog FOO */
SET CATALOG ':memory:';
CREATE TABLE foo.public.bar (baz INTEGER);
START TRANSACTION;
INSERT INTO foo.public.bar (baz) VALUES (1);
ROLLBACK;
SELECT * FROM foo.public.bar;
START TRANSACTION;
INSERT INTO foo.public.bar (baz) VALUES (2);
COMMIT;
SELECT * FROM foo.public.bar;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: START TRANSACTION
-- msg: INSERT 1
-- msg: COMMIT
-- BAZ: 2

/* create_catalog FOO */
CREATE TABLE foo.public.bar (baz INTEGER);
SET CATALOG 'FOO';
START TRANSACTION;
SET CATALOG ':memory:';
START TRANSACTION;
INSERT INTO foo.public.bar (baz) VALUES (1);
ROLLBACK;
SET CATALOG 'FOO';
ROLLBACK;
SELECT * FROM bar;
-- msg: CREATE TABLE 1
-- msg: SET CATALOG 1
-- msg: START TRANSACTION
-- msg: SET CATALOG 1
-- error 25001: invalid transaction state: active sql transaction
-- msg: INSERT 1
-- msg: ROLLBACK
-- msg: SET CATALOG 1
-- error 2D000: invalid transaction termination
