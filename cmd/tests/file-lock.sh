#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
LOG_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE foo (bar INT);' | $VSQL cli $VSQL_FILE

# Another process holds an exclusive lock on the file for a while. The INSERT
# must wait for it to be released.
perl -e 'use Fcntl ":flock"; open(F, "<", $ARGV[0]) or die; flock(F, LOCK_EX);
  sleep 2; open(L, ">>", $ARGV[1]); print L "released\n"; close(L)' \
  $VSQL_FILE $LOG_FILE &
sleep 1

echo 'INSERT INTO foo (bar) VALUES (123);' | $VSQL cli $VSQL_FILE
echo "inserted" >> $LOG_FILE
wait

cat $LOG_FILE
test "$(cat $LOG_FILE | tr '\n' ' ')" = "released inserted "
