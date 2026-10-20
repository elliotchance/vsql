-- # A column reference can be qualified with the table, schema and catalog.
CREATE TABLE t1 (x INT);
INSERT INTO t1 (x) VALUES (123);
SELECT public.t1.x FROM public.t1;
SELECT public.t1.x FROM t1;
SELECT t1.x FROM public.t1;
SELECT ":memory:".public.t1.x FROM t1;
SELECT public.t1.x FROM t1 WHERE public.t1.x = 123 ORDER BY public.t1.x;
SELECT public.t1.* FROM t1;
SELECT ":memory:".public.t1.* FROM t1;
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- X: 123
-- X: 123
-- X: 123
-- X: 123
-- X: 123
-- X: 123
-- X: 123

CREATE TABLE t1 (x INT);
SELECT other.t1.x FROM t1;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unknown column: ":memory:".OTHER.T1.X

CREATE TABLE t1 (x INT);
SELECT other.public.t1.x FROM t1;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: unknown column: OTHER.PUBLIC.T1.X

CREATE TABLE t1 (x INT);
SELECT other.t1.* FROM t1;
-- msg: CREATE TABLE 1
-- error 3F000: invalid schema name: OTHER

CREATE TABLE t1 (x INT);
SELECT a.b.public.t1.x FROM t1;
-- msg: CREATE TABLE 1
-- error 42601: syntax error: invalid column reference: A.B.PUBLIC.T1.X

/* create_catalog FOO */
SET CATALOG 'FOO';
CREATE TABLE public.bar (baz INTEGER);
INSERT INTO public.bar (baz) VALUES (123);
SELECT foo.public.bar.baz AS a, public.bar.baz AS b, bar.baz AS c FROM public.bar;
SELECT ":memory:".public.bar.baz FROM public.bar;
-- msg: SET CATALOG 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- A: 123 B: 123 C: 123
-- error 42601: syntax error: unknown column: ":memory:".PUBLIC.BAR.BAZ
