#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
SQL_FILE="$(mktemp).sql" || exit 1

# By default, errors will stop the process and return a non-zero exit code.
(printf '%s\n' \
    'CREATE foo (bar INT);' \
    'CREATE TABLE bar (bar INT);' \
| $VSQL in $VSQL_FILE) && exit 1 || true

$VSQL out $VSQL_FILE > $SQL_FILE
grep -vR "CREATE TABLE PUBLIC.BAR" $SQL_FILE

# Enable continue on error still returns the non-zero exit code.
(printf '%s\n' \
    'CREATE foo (bar INT);' \
    'CREATE TABLE bar (bar INT);' \
| $VSQL in -continue-on-error $VSQL_FILE) && exit 1 || true

$VSQL out $VSQL_FILE > $SQL_FILE
grep -R "CREATE TABLE PUBLIC.BAR" $SQL_FILE
