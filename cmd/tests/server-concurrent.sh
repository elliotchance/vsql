#!/bin/sh

set -e

if ! command -v psql > /dev/null; then
  echo "skipped: psql is not installed"
  exit 0
fi

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1
PORT=3299
PSQL="psql -h 127.0.0.1 -p $PORT -X -q -t -A"

$VSQL server -p $PORT $VSQL_FILE &
SERVER_PID=$!
trap "kill $SERVER_PID" EXIT
sleep 2

echo 'CREATE TABLE t (x INT);' | $PSQL

# A client that stays connected (and has an uncommitted transaction) must not
# block other clients, or let them see its changes.
(printf "START TRANSACTION;\nINSERT INTO t (x) VALUES (1);\n"; sleep 3) | $PSQL &
sleep 1

echo 'INSERT INTO t (x) VALUES (2);' | $PSQL
echo 'SELECT x FROM t;' | $PSQL > $TXT_FILE
wait $!

# Disconnecting rolled back the transaction.
echo 'SELECT x FROM t;' | $PSQL >> $TXT_FILE

cat $TXT_FILE
test "$(cat $TXT_FILE | tr '\n' ' ')" = "2 2 "
