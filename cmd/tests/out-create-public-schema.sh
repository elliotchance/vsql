#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
SQL_FILE="$(mktemp).sql" || exit 1

echo 'CREATE TABLE foo (bar INT);' | $VSQL in $VSQL_FILE

# Default behavior does not include "CREATE SCHEMA PUBLIC"
$VSQL out $VSQL_FILE > $SQL_FILE

grep -vR "CREATE SCHEMA PUBLIC" $SQL_FILE
grep -R "CREATE TABLE PUBLIC.FOO" $SQL_FILE

# Now include in output.
$VSQL out -create-public-schema $VSQL_FILE > $SQL_FILE

grep -R "CREATE SCHEMA PUBLIC" $SQL_FILE
grep -R "CREATE TABLE PUBLIC.FOO" $SQL_FILE
