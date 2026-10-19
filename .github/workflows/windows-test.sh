#!/bin/sh

# windows-test.sh runs a few statements with the Windows binary, since the CLI
# tests aren't run on Windows. Each statement locks the database file again.

set -e

VSQL="$1"
VSQL_FILE="test.vsql"
rm -f $VSQL_FILE*

echo 'CREATE TABLE products (title VARCHAR(100), price FLOAT);' | $VSQL cli $VSQL_FILE
echo "INSERT INTO products (title, price) VALUES ('Instant Pot', 144.89);" | $VSQL cli $VSQL_FILE
printf "START TRANSACTION;\nINSERT INTO products (title, price) VALUES ('Kettle', 20);\nCOMMIT;\nSELECT * FROM products;\n" | $VSQL cli $VSQL_FILE > out.txt

cat out.txt
grep "TITLE: Instant Pot PRICE: 144.89" out.txt
grep "TITLE: Kettle PRICE: 20" out.txt
