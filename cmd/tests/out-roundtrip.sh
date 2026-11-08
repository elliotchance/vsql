#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
VSQL_FILE2="$(mktemp).vsql" || exit 1
SQL_FILE="$(mktemp).sql" || exit 1
SQL_FILE2="$(mktemp).sql" || exit 1
TXT_FILE="$(mktemp)" || exit 1
TXT_FILE2="$(mktemp)" || exit 1

cat <<EOF | $VSQL in $VSQL_FILE
CREATE TABLE t (
  a SMALLINT, b INTEGER NOT NULL, c BIGINT, d REAL, e DOUBLE PRECISION,
  f NUMERIC(10, 2), g DECIMAL(5, 1), h VARCHAR(20), i CHAR(5), j BOOLEAN,
  k DATE, l TIME(3), m TIME WITH TIME ZONE, n TIMESTAMP(6),
  o TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (b)
);
INSERT INTO t (a, b, c, d, e, f, g, h, i, j, k, l, m, n, o) VALUES (-32768, 1, -9223372036854775808, 1.1e0, 0.1e0 + 0.2e0, 12345678.91, -1234.5, 'it''s', 'ab', TRUE, DATE '2022-06-30', TIME '01:02:03.456', TIME '01:02:03+05:00', TIMESTAMP '2022-06-30 21:47:32.123456', TIMESTAMP '2022-06-30 21:47:32+05:00');
INSERT INTO t (a, b, c, d, e, j) VALUES (32767, 2, 9223372036854775807, -3.4028235e38, 5e-324, FALSE);
INSERT INTO t (b, e) VALUES (3, -1.7976931348623157e308);
CREATE SCHEMA "Mixed";
CREATE TABLE "Mixed"."Table" ("id" INT NOT NULL, "Value" VARCHAR(10), PRIMARY KEY ("id"));
INSERT INTO "Mixed"."Table" ("id", "Value") VALUES (1, '"quoted"');
CREATE INDEX t_h ON t (h DESC, a);
CREATE UNIQUE INDEX t_c ON t (c);
CREATE INDEX "Value" ON "Mixed"."Table" ("Value");
CREATE TABLE u (id INT PRIMARY KEY, b INT UNIQUE, CONSTRAINT u_fk FOREIGN KEY (b) REFERENCES t (b));
INSERT INTO u (id, b) VALUES (1, 1);
CREATE SEQUENCE unused START WITH 10;
CREATE SEQUENCE moved INCREMENT BY 5;
SELECT NEXT VALUE FOR moved FROM (VALUES 1) AS t;
CREATE SEQUENCE "Mixed"."seq" START WITH -5 INCREMENT BY -1;
SELECT NEXT VALUE FOR "Mixed"."seq" FROM (VALUES 1) AS t;
CREATE SEQUENCE past_max START WITH 1 MAXVALUE 2;
SELECT NEXT VALUE FOR past_max FROM (VALUES 1, 2) AS t;
CREATE SEQUENCE past_bigint START WITH 9223372036854775807;
SELECT NEXT VALUE FOR past_bigint FROM (VALUES 1) AS t;
CREATE SEQUENCE cycles START WITH 1 MAXVALUE 2 CYCLE;
SELECT NEXT VALUE FOR cycles FROM (VALUES 1, 2) AS t;
CREATE TABLE z_owner (id INT PRIMARY KEY);
CREATE TABLE a_item (id INT PRIMARY KEY, z_id INT REFERENCES z_owner);
INSERT INTO z_owner (id) VALUES (1);
INSERT INTO a_item (id, z_id) VALUES (1, 1);
CREATE TABLE emp (id INT PRIMARY KEY, dept_id INT, manager_id INT REFERENCES emp);
CREATE TABLE dept (id INT PRIMARY KEY, head_id INT REFERENCES emp);
ALTER TABLE emp ADD CONSTRAINT emp_dept FOREIGN KEY (dept_id) REFERENCES dept (id);
INSERT INTO emp (id, manager_id) VALUES (2, NULL);
INSERT INTO emp (id, manager_id) VALUES (1, 2);
INSERT INTO dept (id, head_id) VALUES (10, 1);
UPDATE emp SET dept_id = 10;
EOF

$VSQL out $VSQL_FILE > $SQL_FILE
cat $SQL_FILE

# A table comes after the table that it references, with the FOREIGN KEY in its
# CREATE TABLE. DEPT and EMP reference each other, so DEPT (the first by name)
# comes first and its FOREIGN KEY is added at the end, like the one of EMP to
# itself, because a row of EMP references a row after it.
test "$(grep -n 'CREATE TABLE "PUBLIC"."Z_OWNER"' $SQL_FILE | cut -d: -f1)" -lt \
  "$(grep -n 'CREATE TABLE "PUBLIC"."A_ITEM"' $SQL_FILE | cut -d: -f1)"
grep -x '  FOREIGN KEY ("Z_ID") REFERENCES "PUBLIC"."Z_OWNER" ("ID")' $SQL_FILE
grep -x '  CONSTRAINT "EMP_DEPT" FOREIGN KEY ("DEPT_ID") REFERENCES "PUBLIC"."DEPT" ("ID")' $SQL_FILE
grep -x 'ALTER TABLE "PUBLIC"."DEPT" ADD CONSTRAINT "DEPT_FOREIGN_KEY_1" FOREIGN KEY ("HEAD_ID") REFERENCES "PUBLIC"."EMP" ("ID");' $SQL_FILE
grep -x 'ALTER TABLE "PUBLIC"."EMP" ADD CONSTRAINT "EMP_FOREIGN_KEY_1" FOREIGN KEY ("MANAGER_ID") REFERENCES "PUBLIC"."EMP" ("ID");' $SQL_FILE
test "$(grep -c 'ADD CONSTRAINT' $SQL_FILE)" -eq 2

# Loading the dump into a new database, and dumping that, must give the same
# result.
$VSQL in $VSQL_FILE2 < $SQL_FILE
$VSQL out $VSQL_FILE2 > $SQL_FILE2
diff $SQL_FILE $SQL_FILE2

# The sequences must also continue from the same place.
for f in $VSQL_FILE $VSQL_FILE2; do
  for seq in unused moved '"Mixed"."seq"' past_max past_bigint cycles; do
    echo "SELECT NEXT VALUE FOR $seq FROM (VALUES 1) AS t;" | $VSQL cli $f 2>&1 | grep -E '^ *-?[0-9]+$|Error'
  done
done > $TXT_FILE
cat $TXT_FILE
LINES=$(wc -l < $TXT_FILE)
head -n $((LINES / 2)) $TXT_FILE > $TXT_FILE2
tail -n $((LINES / 2)) $TXT_FILE | diff $TXT_FILE2 -
