#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE foo (bar INT);' | $VSQL cli $VSQL_FILE

# The file starts with the magic number, then the read and write versions of
# the file format.
test "$(head -c 12 $VSQL_FILE | od -A n -t x1 | tr -d ' \n')" = "7673716c0d0a1a0a00010001"

# Files that aren't vsql databases are refused and left untouched.
echo 'hello' > $TXT_FILE
echo 'SELECT * FROM foo;' | $VSQL cli $TXT_FILE | grep 'not a vsql database'
test "$(cat $TXT_FILE)" = "hello"

# set_header_bytes overwrites the header at the offset with the bytes, which
# are written in octal because printf in some shells doesn't support \x. The
# file is opened first, which copies the log into it and empties the log,
# otherwise the next connection would copy the header in the log over these
# bytes.
set_header_bytes() {
  echo 'SELECT * FROM foo;' | $VSQL cli $VSQL_FILE > /dev/null
  printf "$2" | dd of=$VSQL_FILE bs=1 seek=$1 conv=notrunc 2>/dev/null
}

# Bytes in the reserved part of the header (used by a newer version of vsql)
# are kept.
set_header_bytes 4000 '\022\064'
echo 'INSERT INTO foo (bar) VALUES (1);' | $VSQL cli $VSQL_FILE
test "$(dd if=$VSQL_FILE bs=1 skip=4000 count=2 2>/dev/null | od -A n -t x1 | tr -d ' \n')" = "1234"

# A file with a newer write version can be read, but not changed.
set_header_bytes 10 '\377\377'
echo 'SELECT * FROM foo;' | $VSQL cli $VSQL_FILE | grep -Ex ' *1'

# Including in a transaction, since one that hasn't changed anything doesn't
# need to change the file. A REPEATABLE READ transaction can't publish its
# snapshot, so it starts without one.
printf 'START TRANSACTION;\nSELECT * FROM foo;\nCOMMIT;\nSTART TRANSACTION ISOLATION LEVEL REPEATABLE READ;\nSELECT * FROM foo;\nCOMMIT;\nSELECT * FROM foo;\n' | $VSQL cli -autocommit=false $VSQL_FILE > $TXT_FILE
cat $TXT_FILE
test "$(grep -Ecx ' *1' $TXT_FILE)" = "3"
if grep 'Error' $TXT_FILE; then exit 1; fi
echo 'INSERT INTO foo (bar) VALUES (2);' | $VSQL cli $VSQL_FILE | grep 'Error 25006: read-only sql transaction: database needs file format 65535 to be changed'
if echo 'SELECT * FROM foo;' | $VSQL cli $VSQL_FILE | grep -Ex ' *2'; then
  exit 1
fi

# So can an SQL-transaction that only has queries, which doesn't create the
# isolation file.
rm -f $VSQL_FILE.isolation
test "$(printf 'SELECT * FROM foo;\nSELECT * FROM foo;\n' | $VSQL cli -autocommit=false $VSQL_FILE | grep -cEx ' *1')" = "2"
test ! -e $VSQL_FILE.isolation

# A file with a newer read version can't be opened at all.
set_header_bytes 8 '\377\377'
echo 'SELECT * FROM foo;' | $VSQL cli $VSQL_FILE | grep 'database needs file format 65535 to be read'

# A file with an older read version can't be opened either.
set_header_bytes 8 '\000\000'
echo 'SELECT * FROM foo;' | $VSQL cli $VSQL_FILE | grep 'database uses file format 0, which is older than this version of vsql supports'
