#!/bin/sh

set -e

DIR="$(mktemp -d)" || exit 1
VSQL_FILE="$DIR/db.vsql"
EXPECTED="$(dirname "$0")/out-compat"

$VSQL in $VSQL_FILE < "$EXPECTED/fixture.sql"

for compat in sqlite3 mysql postgresql; do
    $VSQL out -compat $compat $VSQL_FILE > "$DIR/$compat.sql"
    diff "$EXPECTED/$compat.sql" "$DIR/$compat.sql"
done

# Not every machine has it. The others need a server, so the expected output was
# loaded by hand when it changed.
if command -v sqlite3 > /dev/null; then
    sqlite3 -bail "$DIR/db.sqlite" < "$DIR/sqlite3.sql"
    actual="$(sqlite3 "$DIR/db.sqlite" 'SELECT name FROM foo_parent; SELECT g FROM types WHERE si = 7;')"
    if [ "$actual" != "a\\b'c
8" ]; then
        echo "sqlite3: $actual"
        exit 1
    fi
fi

rm -rf "$DIR"
