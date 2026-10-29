#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

# A statement ends with a semicolon, so it can be over many lines. One without
# a semicolon at the end of the input is a syntax error.
printf "CREATE TABLE t\n  (x INT);\nINSERT INTO t (x) /* ; */\nVALUES (1);\nVALUES 2" | $VSQL cli $VSQL_FILE > $TXT_FILE
cat $TXT_FILE
grep 'CREATE TABLE 1' $TXT_FILE
grep 'INSERT 1' $TXT_FILE
grep 'Error 42601: syntax error: a direct SQL statement is one statement that ends with a semicolon' $TXT_FILE

# There's no autocommit: the SQL-transaction stays active until a COMMIT or the
# end of the input, so another process can't see the row before then.
(printf "INSERT INTO t (x) VALUES (2);\n"; sleep 3) | $VSQL cli -autocommit=false $VSQL_FILE &
sleep 1
echo 'SELECT * FROM t WHERE x = 2;' | $VSQL cli $VSQL_FILE > $TXT_FILE
cat $TXT_FILE
grep 'Notice 02000: no data' $TXT_FILE
wait

echo 'SELECT * FROM t WHERE x = 2;' | $VSQL cli $VSQL_FILE > $TXT_FILE
cat $TXT_FILE
grep -Ex ' *2' $TXT_FILE
