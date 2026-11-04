#!/bin/sh

# != (an extension) in a CHECK constraint and a generated column is dumped as
# <>, and the dump must load into a new database and give the same dump.

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
VSQL_FILE2="$(mktemp).vsql" || exit 1
SQL_FILE="$(mktemp).sql" || exit 1
SQL_FILE2="$(mktemp).sql" || exit 1

cat <<EOF | $VSQL in $VSQL_FILE
CREATE TABLE t (
  x INT CONSTRAINT c1 CHECK (x != 1),
  y BOOLEAN GENERATED ALWAYS AS (x != 2)
);
INSERT INTO t (x) VALUES (2);
EOF

$VSQL out $VSQL_FILE > $SQL_FILE
cat $SQL_FILE

grep -q 'CHECK (X <> 1)' $SQL_FILE
grep -q 'GENERATED ALWAYS AS (X <> 2)' $SQL_FILE
if grep -q '!=' $SQL_FILE; then
  echo "the dump must not use !="
  exit 1
fi

$VSQL in $VSQL_FILE2 < $SQL_FILE
$VSQL out $VSQL_FILE2 > $SQL_FILE2
diff $SQL_FILE $SQL_FILE2

# The constraint is still enforced after it's loaded.
echo "INSERT INTO t (x) VALUES (1);" | $VSQL cli $VSQL_FILE2 2>&1 | grep -q 23514

rm -f $VSQL_FILE $VSQL_FILE2 $SQL_FILE $SQL_FILE2
