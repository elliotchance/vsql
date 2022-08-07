#!/bin/sh

set -ex

VSQL_FILE="$(mktemp).vsql" || exit 1
SQL_FILE="$(mktemp).sql" || exit 1

# Loading into a new file.
echo 'CREATE TABLE foo (bar INT);' | $VSQL in $VSQL_FILE

$VSQL out $VSQL_FILE > $SQL_FILE
grep -R "CREATE TABLE PUBLIC.FOO" $SQL_FILE

# Loading into an existing file.
echo 'CREATE TABLE bar (bar INT);' | $VSQL in $VSQL_FILE

$VSQL out $VSQL_FILE > $SQL_FILE
grep -R "CREATE TABLE PUBLIC.FOO" $SQL_FILE
grep -R "CREATE TABLE PUBLIC.BAR" $SQL_FILE
