#!/bin/sh

# windows-test.sh runs a few statements, a short benchmark and the server with
# the Windows binary, since the CLI tests aren't run on Windows. Each statement
# locks the database file again.

set -e

VSQL="$1"
VSQL_FILE="test.vsql"
rm -f $VSQL_FILE*

echo 'CREATE TABLE products (title VARCHAR(100), price FLOAT);' | $VSQL cli $VSQL_FILE
echo "INSERT INTO products (title, price) VALUES ('Instant Pot', 144.89);" | $VSQL cli $VSQL_FILE
printf "START TRANSACTION;\nINSERT INTO products (title, price) VALUES ('Kettle', 20);\nCOMMIT;\nSELECT * FROM products;\n" | $VSQL cli $VSQL_FILE > out.txt

cat out.txt
grep "^Instant Pot | 144.89e0" out.txt
grep "^Kettle      |     20e0" out.txt

$VSQL bench -accounts 1000 -duration 2

VSQL=$VSQL cmd/tests/server-concurrent.sh
