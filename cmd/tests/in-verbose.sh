#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp).sql" || exit 1

(printf '%s\n' \
    'CREATE TABLE foo (bar INT);' \
    'INSERT INTO foo (bar) VALUES (123);' \
| $VSQL in -verbose $VSQL_FILE
) > $TXT_FILE

grep -R "CREATE TABLE 1" $TXT_FILE
grep -R "INSERT 1" $TXT_FILE
