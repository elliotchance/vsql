#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE t (x INT);
INSERT INTO t (x) VALUES (1);' | $VSQL cli $VSQL_FILE

# Set the last transaction ID to the largest 32-bit unsigned integer, so the
# next transactions need more than 32 bits. The bytes are written in octal
# because printf in some shells doesn't support \x.
printf '\000\000\000\000\377\377\377\377' | dd of=$VSQL_FILE bs=1 seek=24 conv=notrunc 2>/dev/null

echo 'INSERT INTO t (x) VALUES (2);
UPDATE t SET x = 3 WHERE x = 1;
START TRANSACTION;
INSERT INTO t (x) VALUES (4);
ROLLBACK;
SELECT * FROM t;' | $VSQL cli $VSQL_FILE > $TXT_FILE

cat $TXT_FILE
grep "X: 3" $TXT_FILE
grep "X: 2" $TXT_FILE
! grep "X: 1" $TXT_FILE
! grep "X: 4" $TXT_FILE

# The transaction ID kept counting past 32 bits.
test "$(dd if=$VSQL_FILE bs=1 skip=24 count=4 2>/dev/null | od -A n -t x1 | tr -d ' \n')" = "00000001"
