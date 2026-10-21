#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE t (id INT NOT NULL, x INT, PRIMARY KEY(id));' | $VSQL cli $VSQL_FILE

# A transaction that is still open in another process must not be mistaken for
# one left behind by a crashed process.
(printf "START TRANSACTION;\nINSERT INTO t (id, x) VALUES (1, 10);\n"; sleep 3; printf "COMMIT;\n") | $VSQL cli $VSQL_FILE &
sleep 1

echo 'INSERT INTO t (id, x) VALUES (2, 20);' | $VSQL cli $VSQL_FILE
wait

echo 'SELECT * FROM t;' | $VSQL cli $VSQL_FILE > $TXT_FILE

cat $TXT_FILE
grep -Ex ' *1 \| *10' $TXT_FILE
grep -Ex ' *2 \| *20' $TXT_FILE
