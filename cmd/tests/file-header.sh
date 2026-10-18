#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE foo (bar INT);' | $VSQL cli $VSQL_FILE

# The file starts with the magic number and the file format version.
test "$(head -c 10 $VSQL_FILE | od -A n -t x1 | tr -d ' \n')" = "7673716c0d0a1a0a000d"

# Files that aren't vsql databases are refused and left untouched.
echo 'hello' > $TXT_FILE
echo 'SELECT * FROM foo;' | $VSQL cli $TXT_FILE | grep 'not a vsql database'
test "$(cat $TXT_FILE)" = "hello"
