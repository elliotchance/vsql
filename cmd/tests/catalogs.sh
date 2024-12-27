#!/bin/sh

set -e

VSQL1_FILE="$(mktemp -d)/file1.abc.vsql" || exit 1
VSQL2_FILE="$(mktemp -d)/file2.def.vsql" || exit 1
TXT_FILE="$(mktemp).sql" || exit 1

echo 'CREATE TABLE foo (bar INT);' | $VSQL cli $VSQL1_FILE
echo 'INSERT INTO foo (bar) VALUES (123);' | $VSQL cli $VSQL1_FILE

echo 'CREATE TABLE foo (baz INT);' | $VSQL cli $VSQL2_FILE
echo 'INSERT INTO foo (baz) VALUES (456);' | $VSQL cli $VSQL2_FILE

echo "SET CATALOG 'file1'; SELECT * FROM public.foo;" | $VSQL cli $VSQL1_FILE $VSQL2_FILE > $TXT_FILE
echo "SET CATALOG 'file2'; SELECT * FROM public.foo;" | $VSQL cli $VSQL1_FILE $VSQL2_FILE >> $TXT_FILE

grep -R "BAR: 123" $TXT_FILE
grep -R "BAZ: 456" $TXT_FILE
