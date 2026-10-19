#!/bin/sh

set -e

# psql is installed on CI, so the test can't be skipped there by mistake.
if ! command -v psql > /dev/null; then
  if [ -n "$CI" ]; then
    echo "psql is not installed"
    exit 1
  fi
  echo "skipped: psql is not installed"
  exit 0
fi

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1
PORT=3298

$VSQL server -p $PORT $VSQL_FILE &
SERVER_PID=$!
trap "kill $SERVER_PID" EXIT
sleep 2

# Statements only send their command tag (not a result set), an INSERT tag has
# an OID, a query with no rows still has columns and errors have their real
# SQLSTATE.
cat <<SQL | psql -h 127.0.0.1 -p $PORT -X -e > $TXT_FILE 2>&1
\set VERBOSITY verbose
CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1), (2);
SELECT * FROM t WHERE x > 5;
UPDATE t SET x = 3 WHERE x = 2;
SELECT * FROM nope;
SQL

cat $TXT_FILE

# The catalog name comes from the (random) file name.
tr -d '\r' < $TXT_FILE | sed 's/"[^"]*".PUBLIC/CATALOG.PUBLIC/' > $TXT_FILE.actual
cat <<OUT | diff - $TXT_FILE.actual
CREATE TABLE t (x INT);
CREATE TABLE 1
INSERT INTO t (x) VALUES (1), (2);
INSERT 0 2
SELECT * FROM t WHERE x > 5;
 X 
---
(0 rows)

UPDATE t SET x = 3 WHERE x = 2;
UPDATE 1
SELECT * FROM nope;
ERROR:  42P01: no such table: CATALOG.PUBLIC.NOPE
OUT
