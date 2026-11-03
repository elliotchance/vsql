#!/bin/sh

set -e

# This changes to a temporary directory, and VSQL can be a relative path.
VSQL="$(realpath "$VSQL")"

DIR="$(mktemp -d)" || exit 1
VSQL_FILE="$DIR/test.vsql"
cd "$DIR"

query() {
    echo "$1" | $VSQL cli $VSQL_FILE
}

# -file and the format comes from its extension.
printf 'CREATE SCHEMA foo;\n' > schema.sql
$VSQL in -file schema.sql $VSQL_FILE

# -schema is the current schema of a SQL file.
printf 'CREATE TABLE t (x INT);\nINSERT INTO t (x) VALUES (1);\n' > load.sql
$VSQL in -file load.sql -schema FOO $VSQL_FILE
query 'SELECT x FROM foo.t;' | grep -x 1

# -table, -create-table takes the definitions of the columns. By default, nothing
# is printed if there are no problems.
printf 'id,name,skip\n1,one,a\n2,two,b\n' > people.csv
$VSQL in -file people.csv -schema foo -table people -create-table 'ID INTEGER, NAME VARCHAR(10)' -map id=ID -map name=NAME $VSQL_FILE > out.txt
test ! -s out.txt
query 'SELECT name FROM foo.people WHERE id = 2;' | grep -x two

# -format with stdin, and -map only imports the mapped fields.
query 'CREATE TABLE p (a INT, b VARCHAR(10));' > /dev/null
printf 'x\ty\tz\n1\tone\t?\n' | $VSQL in -format tsv -table p -map x=A -map y=B $VSQL_FILE
query 'SELECT b FROM p WHERE a = 1;' | grep -x one

# JSON.
printf '[{"a": 2, "b": "two"}]' > rows.json
$VSQL in -file rows.json -table p $VSQL_FILE
query 'SELECT b FROM p WHERE a = 2;' | grep -x two

# -single-transaction rolls back if it stops at an error.
printf 'INSERT INTO p (a) VALUES (10);\nINSERT INTO nope (a) VALUES (1);\n' > bad.sql
$VSQL in -file bad.sql -single-transaction $VSQL_FILE && exit 1
query 'SELECT COUNT(*) AS c FROM p WHERE a = 10;' | grep -x 0

# Without it, the statements before the error are kept.
$VSQL in -file bad.sql $VSQL_FILE && exit 1
query 'SELECT COUNT(*) AS c FROM p WHERE a = 10;' | grep -x 1

# -continue-on-error keeps the others, in one transaction or not. It still fails.
printf 'INSERT INTO nope (a) VALUES (1);\nINSERT INTO p (a) VALUES (11);\n' > bad.sql
$VSQL in -file bad.sql -single-transaction -continue-on-error $VSQL_FILE && exit 1
query 'SELECT COUNT(*) AS c FROM p WHERE a = 11;' | grep -x 1

# Rows that fail are reported by their line, and the others are kept.
query 'CREATE TABLE u (id INT PRIMARY KEY);' > /dev/null
printf 'id\n1\n1\n2\n' > u.csv
$VSQL in -file u.csv -table u -continue-on-error $VSQL_FILE > out.txt && exit 1
grep '^3 7/9 ERROR 23505 ' out.txt
query 'SELECT COUNT(*) AS c FROM u;' | grep -x 2

# -verbose prints each statement with its line, and the bytes read of the file. A
# line of 0 isn't in the file. What failed has no line of its own.
printf -- "-- comment\nCREATE TABLE c (x INT);\n\nINSERT INTO c (x)\n  VALUES (1), (2), (3);\nUPDATE c SET x = 9 WHERE x > 1;\nDELETE FROM c WHERE x = 7;\nCREATE TABLE c (x INT);\nSELECT * FROM c;\nDROP TABLE c;\n" > ops.sql
$VSQL in -file ops.sql -verbose -continue-on-error $VSQL_FILE > out.txt && exit 1
SIZE="$(wc -c < ops.sql | tr -d ' ')"
grep -x "2 34/$SIZE CREATE TABLE 1" out.txt
grep -x "4 77/$SIZE INSERT 3" out.txt
grep -x "6 109/$SIZE UPDATE 2" out.txt
grep "^7 136/$SIZE NOTICE 02000 no data" out.txt
grep -x "7 136/$SIZE DELETE 0" out.txt
grep "^8 160/$SIZE ERROR 42P07 " out.txt
grep -x "9 177/$SIZE SELECT 3" out.txt
grep -x "10 191/$SIZE DROP TABLE 1" out.txt

# A NOTICE needs -verbose.
$VSQL in -file ops.sql -continue-on-error $VSQL_FILE > out.txt && exit 1
if grep -q 'NOTICE\|UPDATE' out.txt; then exit 1; fi

# The size isn't known for stdin.
printf 'CREATE TABLE s (x INT);\n' | $VSQL in -verbose $VSQL_FILE | grep -x '1 23/? CREATE TABLE 1'

# A SQL file stops at an error, with a ROLLBACK if there's a transaction.
printf 'INSERT INTO nope (a) VALUES (1);\n' > bad.sql
$VSQL in -file bad.sql -single-transaction $VSQL_FILE > out.txt && exit 1
grep '^1 32/33 ERROR 42P01 ' out.txt
grep -x '0 32/33 ROLLBACK' out.txt
$VSQL in -file bad.sql -single-transaction -verbose $VSQL_FILE > out.txt && exit 1
grep -x '0 0/33 START TRANSACTION' out.txt
grep -x '0 32/33 ROLLBACK' out.txt
$VSQL in -file bad.sql $VSQL_FILE > out.txt && exit 1
if grep -q ROLLBACK out.txt; then exit 1; fi

# -single-transaction with a file that has its own transactions.
printf 'START TRANSACTION;\nCOMMIT;\n' > own.sql
$VSQL in -file own.sql -single-transaction $VSQL_FILE > out.txt && exit 1
grep '^1 18/27 ERROR HY000 a file with its own transactions' out.txt
grep ' ROLLBACK$' out.txt
$VSQL in -file own.sql -verbose $VSQL_FILE | grep -x '2 26/27 COMMIT'

# A transaction that's left open is rolled back, with a warning.
printf 'START TRANSACTION;\nCREATE TABLE opened (x INT);\n' > open.sql
$VSQL in -file open.sql $VSQL_FILE > out.txt
grep '^0 .* WARNING 01000 the file left a transaction open' out.txt
grep ' ROLLBACK$' out.txt
query 'SELECT * FROM opened;' | grep -i 'no such table'

# Rows are always in one transaction, with an INSERT for each batch of 200.
query 'CREATE TABLE big (id INT);' > /dev/null
(echo id; i=1; while [ $i -le 445 ]; do echo $i; i=$((i + 1)); done) > big.csv
$VSQL in -file big.csv -table big -verbose $VSQL_FILE > out.txt
SIZE="$(wc -c < big.csv | tr -d ' ')"
test "$(cut -d' ' -f1,3- out.txt | tr '\n' ';')" = '0 START TRANSACTION;2 INSERT 200;202 INSERT 200;402 INSERT 45;0 COMMIT;'
grep -x "402 $SIZE/$SIZE INSERT 45" out.txt

# A problem late in a file rolls back what was already inserted, even with
# -continue-on-error.
(cat big.csv; printf '"1\n') > broken.csv
$VSQL in -file broken.csv -table big -continue-on-error -verbose $VSQL_FILE > out.txt && exit 1
grep ' INSERT 200$' out.txt
grep '^447 .* ERROR HY000 a quote is never closed' out.txt
grep ' ROLLBACK$' out.txt
query 'SELECT COUNT(*) AS c FROM big;' | grep -E '^ *445$'

# So does a row of the wrong size, a bad JSON file, and a table that isn't there.
query 'CREATE TABLE b (a INT, c INT);' > /dev/null
printf 'a,c\n1,2\n3\n' > short.csv
$VSQL in -file short.csv -table b $VSQL_FILE > out.txt && exit 1
grep '^3 .* ERROR HY000 has 1 values, but there are 2 columns' out.txt
grep ' ROLLBACK$' out.txt
printf '[{"a": 1},\n{"a": }]' > bad.json
$VSQL in -file bad.json -table b $VSQL_FILE > out.txt && exit 1
grep '^2 .* ERROR HY000 expected a value' out.txt
$VSQL in -file u.csv -table nope $VSQL_FILE > out.txt && exit 1
grep '^0 .* ERROR HY000 no such table' out.txt
query 'SELECT COUNT(*) AS c FROM b;' | grep -E '^ *0$'

# -create-table is in the same transaction.
printf 'x\n"1\n' > unclosed.csv
$VSQL in -file unclosed.csv -table broken -create-table 'X INT' $VSQL_FILE > out.txt && exit 1
query 'SELECT * FROM broken;' | grep -i 'no such table'

# JSON keys can differ between rows, which is a new INSERT.
query 'CREATE TABLE k (a INT, b INT DEFAULT 7);' > /dev/null
printf '[{"a": 1, "b": 2},\n{"a": 3},\n{"a": 4}]' > keys.json
$VSQL in -file keys.json -table k -verbose $VSQL_FILE > out.txt
grep '^1 .* INSERT 1$' out.txt
grep '^2 .* INSERT 2$' out.txt
query 'SELECT b FROM k WHERE a = 4;' | grep -x 7

# A statement that's split across reads of the file, and a comment at the end of
# one, is still whole.
awk 'BEGIN { print "CREATE TABLE l (a VARCHAR(70000));"; for (i = 0; i < 4; i++) { s = ""; for (j = 0; j < 30000; j++) s = s "x;"; print "-- comment; here\nINSERT INTO l (a) VALUES (\x27" s "\x27);" } }' > long.sql
$VSQL in -file long.sql $VSQL_FILE
query 'SELECT COUNT(*) AS c FROM l;' | grep -E '^ *4$'

# Bad options.
$VSQL in -format nope $VSQL_FILE < /dev/null && exit 1
$VSQL in -format csv $VSQL_FILE < /dev/null && exit 1
$VSQL in -file load.sql -table p $VSQL_FILE && exit 1
$VSQL in -format csv -table p -map x $VSQL_FILE < /dev/null && exit 1
$VSQL in -report json $VSQL_FILE < /dev/null && exit 1
$VSQL in -progress $VSQL_FILE < /dev/null && exit 1
$VSQL in -format csv -table p -single-transaction $VSQL_FILE < /dev/null && exit 1
$VSQL in -create-table 'X INT' $VSQL_FILE < /dev/null && exit 1

rm -rf "$DIR"
