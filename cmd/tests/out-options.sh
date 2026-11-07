#!/bin/sh

set -e

DIR="$(mktemp -d)" || exit 1
VSQL_FILE="$DIR/db.vsql"

printf '%s\n' \
    'CREATE SCHEMA foo;' \
    'CREATE SCHEMA nothing;' \
    'CREATE SEQUENCE foo.seq1;' \
    'CREATE TABLE foo.parent (id INT NOT NULL PRIMARY KEY, name VARCHAR(20));' \
    'CREATE TABLE foo.child (id INT NOT NULL PRIMARY KEY, pid INT, CONSTRAINT fk1 FOREIGN KEY (pid) REFERENCES foo.parent (id));' \
    "INSERT INTO foo.parent (id, name) VALUES (1, 'a,b');" \
    "INSERT INTO foo.parent (id, name) VALUES (2, '');" \
    'INSERT INTO foo.parent (id, name) VALUES (3, NULL);' \
    'CREATE INDEX parent_name ON foo.parent (name);' \
    'CREATE TABLE baz (x INT, b BOOLEAN, s VARCHAR(20));' \
    "INSERT INTO baz (x, b, s) VALUES (7, TRUE, 'q\"t');" \
| $VSQL in $VSQL_FILE

# check_out compares the output of "vsql out" (with CRs shown) to the expected
# lines.
check_out() {
    expected="$1"
    shift
    actual="$($VSQL out "$@" $VSQL_FILE | tr '\r' '~')"
    if [ "$actual" != "$expected" ]; then
        echo "vsql out $*"
        echo "expected: $expected"
        echo "actual:   $actual"
        exit 1
    fi
}

# check_error checks that "vsql out" fails with a message.
check_error() {
    expected="$1"
    shift
    if actual="$($VSQL out "$@" $VSQL_FILE 2>&1)"; then
        echo "vsql out $* should have failed"
        exit 1
    fi
    case "$actual" in
        *"$expected"*) ;;
        *)
            echo "vsql out $*"
            echo "expected: $expected"
            echo "actual:   $actual"
            exit 1
            ;;
    esac
}

# SQL is in a transaction, unless -no-transaction.
$VSQL out $VSQL_FILE | head -n 1 | grep -x 'START TRANSACTION;'
$VSQL out $VSQL_FILE | tail -n 1 | grep -x 'COMMIT;'
if $VSQL out -no-transaction $VSQL_FILE | grep 'TRANSACTION\|COMMIT'; then exit 1; fi

# Patterns ignore case, and -exclude is taken from what's included.
$VSQL out -include 'foo.par*' $VSQL_FILE > $DIR/out.sql
grep 'CREATE TABLE "FOO"."PARENT"' $DIR/out.sql
if grep 'CHILD\|SEQ1\|BAZ\|NOTHING' $DIR/out.sql; then exit 1; fi
$VSQL out -include 'FOO.*' -exclude 'foo.fk1' -exclude '*.seq?' $VSQL_FILE > $DIR/out.sql
grep 'CREATE TABLE "FOO"."CHILD"' $DIR/out.sql
if grep 'FK1\|SEQ1\|BAZ' $DIR/out.sql; then exit 1; fi
# An index is in the output with its table. The index that the FOREIGN KEY made
# also needs the FOREIGN KEY, which is left out here.
grep -x 'CREATE INDEX "PARENT_NAME" ON "FOO"."PARENT" ("NAME");' $DIR/out.sql
$VSQL out $VSQL_FILE | grep -x 'CREATE INDEX "FK1" ON "FOO"."CHILD" ("PID");'
if $VSQL out -data-only $VSQL_FILE | grep 'INDEX'; then exit 1; fi
$VSQL out -schema-only $VSQL_FILE | grep -x 'CREATE INDEX "PARENT_NAME" ON "FOO"."PARENT" ("NAME");'

# A foreign key isn't left out because its table is.
$VSQL out -exclude 'foo.parent' $VSQL_FILE > $DIR/out.sql
grep 'ADD CONSTRAINT "FK1"' $DIR/out.sql

# The output of a whole file loads again.
$VSQL out $VSQL_FILE > $DIR/out.sql
$VSQL in $DIR/other.vsql < $DIR/out.sql
$VSQL out $DIR/other.vsql | diff - $DIR/out.sql

# -file is the same as stdout.
$VSQL out -file $DIR/file.sql $VSQL_FILE
$VSQL out $VSQL_FILE | diff - $DIR/file.sql

# A failed export doesn't replace the file or leave anything behind.
check_error 'does not match anything' -file $DIR/file.sql -include 'nope.*'
$VSQL out $VSQL_FILE | diff - $DIR/file.sql
if ls $DIR | grep tmp; then exit 1; fi

# CSV uses CRLF, TSV doesn't, and an empty string isn't NULL.
check_out 'ID,NAME~
1,"a,b"~
2,""~
3,~' -format csv -query 'SELECT * FROM foo.parent ORDER BY id'
check_out '1	a,b
2	""
3	' -format tsv -no-header -query 'SELECT * FROM foo.parent ORDER BY id'
check_out 'X	B	S
7	TRUE	"q""t"' -format tsv -query 'SELECT * FROM baz'
check_out '1,"a,b"~' -format csv -no-header -query 'SELECT * FROM foo.parent WHERE id = 1'

# -null changes how NULL is written, a string with the same value is quoted.
check_out 'ID,NAME~
2,""~
3,\N~' -format csv -null '\N' -query 'SELECT * FROM foo.parent WHERE id > 1 ORDER BY id'
check_out '3	NULL' -format tsv -no-header -null NULL -query 'SELECT * FROM foo.parent WHERE id = 3'
check_out '"\N",\N~' -format csv -no-header -null "\\N" -query "SELECT '\\N' AS a, name FROM foo.parent WHERE id = 3"

# Each value of JSON is on its own line.
check_out '[
  {
    "X": 7,
    "B": true,
    "S": "q\"t"
  }
]' -format json -query 'SELECT * FROM baz'
check_out '[]' -format json -query 'SELECT * FROM baz WHERE x = 0'

# Each "?" is an environment variable. \N is NULL and an empty one is a string.
export P1='a,b'
check_out 'ID~
1~' -format csv -query 'SELECT id FROM foo.parent WHERE name = ?'
export P1=''
check_out 'ID~
2~' -format csv -query 'SELECT id FROM foo.parent WHERE name = ?'
export P1='\N'
check_out '[
  {
    "V": null
  }
]' -format json -query 'SELECT ? AS v FROM baz'
export P1=7
check_out '7~' -format csv -no-header -query 'SELECT x FROM baz WHERE x = CAST(? AS INT)'
unset P1
check_error 'environment variables are not set: P1, P2' -format csv -query 'SELECT x FROM baz WHERE s = ? AND s = ?'
export P2=a
check_error 'environment variables are not set: P1' -format csv -query 'SELECT x FROM baz WHERE s = ? AND s = ?'
unset P2

# Flags that can't be used together.
check_error '-format must be' -format xml
check_error '-format csv needs -query' -format csv
check_error '-format json needs -query' -format json
check_error '-query needs -format' -query 'SELECT * FROM baz'
check_error '-query needs -format' -format sql -query 'SELECT * FROM baz'
check_error 'cannot be used with -include' -format csv -include 'a.b' -query 'SELECT * FROM baz'
check_error 'cannot be used with -include' -format csv -exclude 'a.b' -query 'SELECT * FROM baz'
check_error '-no-header needs' -no-header
check_error '-no-header needs' -format json -no-header -query 'SELECT * FROM baz'
check_error '-null needs' -null x
check_error '-null needs' -format json -null x -query 'SELECT * FROM baz'
check_error '-no-transaction needs' -format csv -no-transaction -query 'SELECT * FROM baz'
check_error '-create-public-schema needs' -format csv -create-public-schema -query 'SELECT * FROM baz'

check_error '-compat must be' -compat nope
check_error '-compat needs' -format csv -compat mysql -query 'SELECT * FROM baz'
check_error 'cannot be used with -compat' -compat mysql -create-public-schema
check_error '-data-only cannot be used with -schema-only' -data-only -schema-only
check_error '-data-only needs' -format csv -data-only -query 'SELECT * FROM baz'
check_error '-schema-only needs' -format csv -schema-only -query 'SELECT * FROM baz'

# -schema-only followed by -data-only is the same as the whole dump.
COPY_FILE="$DIR/copy.vsql"
$VSQL out -schema-only $VSQL_FILE | $VSQL in $COPY_FILE
$VSQL out -data-only $VSQL_FILE | $VSQL in $COPY_FILE
if [ "$($VSQL out $COPY_FILE)" != "$($VSQL out $VSQL_FILE)" ]; then
    echo '-schema-only and -data-only are not the same as the whole dump'
    exit 1
fi

# -query is one query.
check_error 'must be a query, not INSERT' -format csv -query 'INSERT INTO baz (x) VALUES (1)'
check_error 'must be a query, not EXPLAIN' -format csv -query 'EXPLAIN SELECT * FROM baz'
check_error 'must be a single query' -format csv -query 'SELECT * FROM baz; SELECT * FROM baz'
check_error 'must be a single query' -format csv -query '-- nothing'

# Flags after the file would be ignored, so they're an error.
if actual="$($VSQL out $VSQL_FILE -format json 2>&1)"; then exit 1; fi
case "$actual" in
    *'flags must be before the file'*) ;;
    *) echo "$actual"; exit 1 ;;
esac

rm -rf "$DIR"
