#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);
CREATE SEQUENCE seq1;' | $VSQL cli $VSQL_FILE

# Readers only hold a shared lock, so they must not change the file at all.
BEFORE=$(cksum < $VSQL_FILE)
echo 'SELECT * FROM t;' | $VSQL cli $VSQL_FILE
test "$(cksum < $VSQL_FILE)" = "$BEFORE"

# So is a transaction that hasn't changed anything, including one that a query
# starts without autocommit.
printf 'START TRANSACTION;\nSELECT * FROM t;\nCOMMIT;\n' | $VSQL cli $VSQL_FILE
printf 'SELECT * FROM t;\nROLLBACK;\nSELECT * FROM t;\n' | $VSQL cli -autocommit=false $VSQL_FILE
test "$(cksum < $VSQL_FILE)" = "$BEFORE"

# Except for NEXT VALUE FOR, which needs to take a write lock instead.
echo 'SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;' | $VSQL cli $VSQL_FILE > $TXT_FILE
echo 'SELECT NEXT VALUE FOR seq1 FROM (VALUES 1) AS t;' | $VSQL cli $VSQL_FILE >> $TXT_FILE

cat $TXT_FILE
grep -Ex ' *1' $TXT_FILE
grep -Ex ' *2' $TXT_FILE
