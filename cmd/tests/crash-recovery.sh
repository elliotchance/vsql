#!/bin/sh

set -e

# Every statement that changes the file must be atomic, even if the process
# stops part way through writing it. VSQL_CRASH_AT stops the process at each
# point that writes to the write-ahead log or the database file in turn.

BASE_FILE="$(mktemp).vsql" || exit 1
VSQL_FILE="$(mktemp).vsql" || exit 1
TXT_FILE="$(mktemp)" || exit 1

A=$(head -c 300 /dev/zero | tr '\0' a)
B=$(head -c 450 /dev/zero | tr '\0' b)

echo 'CREATE TABLE t (id INT NOT NULL, s VARCHAR(500), PRIMARY KEY (id));' | $VSQL cli $BASE_FILE > /dev/null
i=0
while [ $i -lt 40 ]; do
  echo "INSERT INTO t (id, s) VALUES ($i, '$A');"
  i=$((i + 1))
done | $VSQL cli $BASE_FILE > /dev/null

# The rows get longer, so pages are split as well as changed.
crash_at=1
while true; do
  cp $BASE_FILE $VSQL_FILE
  rm -f $VSQL_FILE.wal

  if echo "UPDATE t SET s = '$B';" | VSQL_CRASH_AT=$crash_at $VSQL cli $VSQL_FILE > /dev/null 2>&1; then
    # It wasn't stopped, so every point has been tested.
    break
  fi

  # Reading recovers the file, which must contain all or none of the UPDATE.
  echo "SELECT COUNT(*) FROM t; SELECT COUNT(*) FROM t WHERE s = '$B';" | $VSQL cli $VSQL_FILE > $TXT_FILE
  total=$(grep -Ex ' *[0-9]+' $TXT_FILE | tr -d ' ' | sed -n 1p)
  changed=$(grep -Ex ' *[0-9]+' $TXT_FILE | tr -d ' ' | sed -n 2p)
  if [ "$total" != "40" ] || { [ "$changed" != "0" ] && [ "$changed" != "40" ]; }; then
    echo "crash at $crash_at: expected 40 rows with 0 or 40 changed, got: $total, $changed"
    cat $TXT_FILE
    exit 1
  fi

  # The file can still be changed.
  echo "DELETE FROM t WHERE id = 0; SELECT COUNT(*) FROM t;" | $VSQL cli $VSQL_FILE > $TXT_FILE
  grep -qEx ' *39' $TXT_FILE || { echo "crash at $crash_at: cannot change file"; cat $TXT_FILE; exit 1; }

  crash_at=$((crash_at + 1))
done

echo "tested $((crash_at - 1)) crash points"
test $crash_at -gt 10

# A ROLLBACK TO SAVEPOINT writes to the file too. The transaction either isn't
# committed at all, or it only has what was before the savepoint.
crash_at=1
while true; do
  cp $BASE_FILE $VSQL_FILE
  rm -f $VSQL_FILE.wal

  if printf "%s\n" "START TRANSACTION;" "UPDATE t SET s = 'x' WHERE id = 1;" "SAVEPOINT p;" "UPDATE t SET s = '$B';" "DELETE FROM t WHERE id = 2;" "ROLLBACK TO SAVEPOINT p;" "COMMIT;" | VSQL_CRASH_AT=$crash_at $VSQL cli $VSQL_FILE > /dev/null 2>&1; then
    finished=1
  else
    finished=0
  fi

  echo "SELECT COUNT(*) FROM t; SELECT COUNT(*) FROM t WHERE s = '$B'; SELECT COUNT(*) FROM t WHERE s = 'x';" | $VSQL cli $VSQL_FILE > $TXT_FILE
  total=$(grep -Ex ' *[0-9]+' $TXT_FILE | tr -d ' ' | sed -n 1p)
  changed=$(grep -Ex ' *[0-9]+' $TXT_FILE | tr -d ' ' | sed -n 2p)
  kept=$(grep -Ex ' *[0-9]+' $TXT_FILE | tr -d ' ' | sed -n 3p)
  if [ "$total" != "40" ] || [ "$changed" != "0" ] || { [ "$kept" != "0" ] && [ "$kept" != "1" ]; }; then
    echo "savepoint crash at $crash_at: expected 40, 0, and 0 or 1, got: $total, $changed, $kept"
    cat $TXT_FILE
    exit 1
  fi

  if [ "$finished" = "1" ]; then
    test "$kept" = "1" || { echo "savepoint: the commit was lost"; exit 1; }
    break
  fi
  crash_at=$((crash_at + 1))
done

echo "tested $((crash_at - 1)) savepoint crash points"
test $crash_at -gt 5
