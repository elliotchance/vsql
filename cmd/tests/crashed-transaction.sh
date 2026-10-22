#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE t (id INT NOT NULL, x INT, PRIMARY KEY(id));
INSERT INTO t (id, x) VALUES (1, 10);
INSERT INTO t (id, x) VALUES (2, 20);' | $VSQL cli $VSQL_FILE

# Start a transaction, change some rows and then kill the process before it can
# finish.
(printf "START TRANSACTION;\nUPDATE t SET x = 11 WHERE id = 1;\nDELETE FROM t WHERE id = 2;\nINSERT INTO t (id, x) VALUES (3, 30);\nCREATE TABLE t2 (x INT);\n"; sleep 5) | $VSQL cli $VSQL_FILE &
PID=$!
sleep 2
kill -9 $PID

# The next connection must roll back the dead transaction.
echo 'UPDATE t SET x = 12 WHERE id = 1;
SELECT * FROM t;
CREATE TABLE t2 (y INT);' | $VSQL cli $VSQL_FILE > $TXT_FILE

cat $TXT_FILE
grep "UPDATE 1" $TXT_FILE
grep -Ex ' *1 \| *12' $TXT_FILE
grep -Ex ' *2 \| *20' $TXT_FILE
! grep -E '^ *3 \|' $TXT_FILE
grep "CREATE TABLE 1" $TXT_FILE
