#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

# A FOREIGN KEY that references the PRIMARY KEY of another table. The CLI is
# built with -prod, which used to give the FOREIGN KEY the wrong referenced
# columns.
cat <<EOF2 | $VSQL in $VSQL_FILE
CREATE TABLE parent (id INT PRIMARY KEY);
CREATE TABLE child (parent_id INT REFERENCES parent);
INSERT INTO parent (id) VALUES (1);
INSERT INTO child (parent_id) VALUES (1);
EOF2

echo 'INSERT INTO child (parent_id) VALUES (2);' | $VSQL cli $VSQL_FILE > $TXT_FILE 2>&1 || true
cat $TXT_FILE
grep -F "23503" $TXT_FILE

echo 'SELECT * FROM child;' | $VSQL cli $VSQL_FILE > $TXT_FILE
cat $TXT_FILE
grep -E "^ *1$" $TXT_FILE

rm $VSQL_FILE $TXT_FILE
