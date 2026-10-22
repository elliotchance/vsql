#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
SQL_FILE="$(mktemp).sql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

# Statements can be longer than a line, or share one. A semicolon in a string
# or delimited identifier doesn't end the statement, and spaces are kept (they
# used to be lost at every 100th byte, see #476).
A=$(head -c 72 /dev/zero | tr '\0' a)
cat <<EOF2 | $VSQL in $VSQL_FILE
CREATE TABLE "a;b" (s VARCHAR(200));
INSERT INTO "a;b" (s) VALUES ('$A b'); INSERT INTO "a;b" (s)
  VALUES ('x; y'), ('it''s; ok')
EOF2

echo 'SELECT * FROM "a;b";' | $VSQL cli $VSQL_FILE > $TXT_FILE
cat $TXT_FILE
grep -Fx "$A b" $TXT_FILE
grep -Fx "x; y" $TXT_FILE
grep -Fx "it's; ok" $TXT_FILE
