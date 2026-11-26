-- # Views are dumped after everything else, as they were written. See also
-- # impl_dump_round_trip.sql.
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
CREATE VIEW v (y) AS SELECT x * 10 FROM t /* tens */ WHERE x > 1;
/* out */
/* in */
SELECT * FROM v;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE VIEW 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "X" INTEGER
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (1);
-- out: INSERT INTO "PUBLIC"."T" ("X") VALUES (2);
-- out: CREATE VIEW "PUBLIC"."V" ("Y") AS SELECT x * 10 FROM t /* tens */ WHERE x > 1;
-- Y: 20

-- # A view comes after the views that it reads, otherwise they're in the order
-- # of their names.
CREATE VIEW c AS SELECT 1 AS x FROM (VALUES 0) AS t;
CREATE VIEW "b" AS SELECT x + 1 AS x FROM c;
CREATE VIEW a AS SELECT x + 1 AS x FROM "b";
/* out */
/* in */
SELECT * FROM a;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- out: CREATE VIEW "PUBLIC"."C" ("X") AS SELECT 1 AS x FROM (VALUES 0) AS t;
-- out: CREATE VIEW "PUBLIC"."b" ("X") AS SELECT x + 1 AS x FROM c;
-- out: CREATE VIEW "PUBLIC"."A" ("X") AS SELECT x + 1 AS x FROM "b";
-- X: 3

-- # A name in a query that's the same as another view only changes the order.
-- # When the views seem to read each other, they're in the order of their names.
CREATE VIEW q AS SELECT 1 AS p FROM (VALUES 0) AS t;
CREATE VIEW p AS SELECT 2 AS q FROM (VALUES 0) AS t;
/* out */
/* in */
SELECT * FROM p, q;
-- msg: CREATE VIEW 1
-- msg: CREATE VIEW 1
-- out: CREATE VIEW "PUBLIC"."P" ("Q") AS SELECT 2 AS q FROM (VALUES 0) AS t;
-- out: CREATE VIEW "PUBLIC"."Q" ("P") AS SELECT 1 AS p FROM (VALUES 0) AS t;
-- Q: 2 P: 1

-- # A view in another schema still reads the tables of its own schema.
CREATE SCHEMA s;
CREATE TABLE s.t (x INT);
INSERT INTO s.t (x) VALUES (5);
CREATE VIEW s.v AS SELECT x FROM t;
/* out */
/* in */
SELECT * FROM s.v;
-- msg: CREATE SCHEMA 1
-- msg: CREATE TABLE 1
-- msg: INSERT 1
-- msg: CREATE VIEW 1
-- out: CREATE SCHEMA "S";
-- out: CREATE TABLE "S"."T" (
-- out:   "X" INTEGER
-- out: );
-- out: INSERT INTO "S"."T" ("X") VALUES (5);
-- out: CREATE VIEW "S"."V" ("X") AS SELECT x FROM t;
-- X: 5

-- # A view comes after the foreign keys that are added at the end.
CREATE TABLE t (id INT PRIMARY KEY, parent INT, CONSTRAINT fk FOREIGN KEY (parent) REFERENCES t (id));
INSERT INTO t (id, parent) VALUES (1, NULL), (2, 1);
CREATE VIEW v AS SELECT * FROM t WHERE parent IS NOT NULL;
/* out */
/* in */
SELECT * FROM v;
-- msg: CREATE TABLE 1
-- msg: INSERT 2
-- msg: CREATE VIEW 1
-- out: CREATE TABLE "PUBLIC"."T" (
-- out:   "ID" INTEGER NOT NULL,
-- out:   "PARENT" INTEGER,
-- out:   PRIMARY KEY ("ID")
-- out: );
-- out: INSERT INTO "PUBLIC"."T" ("ID", "PARENT") VALUES (1, NULL);
-- out: INSERT INTO "PUBLIC"."T" ("ID", "PARENT") VALUES (2, 1);
-- out: ALTER TABLE "PUBLIC"."T" ADD CONSTRAINT "FK" FOREIGN KEY ("PARENT") REFERENCES "PUBLIC"."T" ("ID");
-- out: CREATE VIEW "PUBLIC"."V" ("ID", "PARENT") AS SELECT * FROM t WHERE parent IS NOT NULL;
-- ID: 2 PARENT: 1
