#!/bin/sh

# hello-test.sh checks that a release binary starts, creates a new database
# file, writes a row to it and reads it back in a separate process.

set -e

VSQL="$1"
VSQL_FILE="${RUNNER_TEMP:-/tmp}/hello.vsql"
rm -f "$VSQL_FILE"*

printf "CREATE TABLE hello (message VARCHAR(20));\nINSERT INTO hello (message) VALUES ('Hello, vsql!');\n" | $VSQL cli "$VSQL_FILE"

echo "SELECT * FROM hello;" | $VSQL cli "$VSQL_FILE" > "$VSQL_FILE.txt"

cat "$VSQL_FILE.txt"
grep -qF 'Hello, vsql!' "$VSQL_FILE.txt"
rm -f "$VSQL_FILE"*
