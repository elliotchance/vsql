#!/bin/sh

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1
LOG_FILE="$(mktemp)" || exit 1

echo 'CREATE TABLE foo (bar INT);' | $VSQL cli $VSQL_FILE

# Another process holds an exclusive lock on the file for a while. The INSERT
# must wait for it to be released.
#
# On Windows, vsql locks a separate file (the database file's name with .lock
# on the end, see vsql/flock_windows.c.v) with LockFileEx, which the MSYS perl
# can't do, so PowerShell locks it instead. PowerShell can take a few seconds
# to start, so the INSERT waits until it has the lock, and its log lines end
# with \r\n.
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*)
    LOCKED_FILE="$(mktemp)" || exit 1
    rm -f $LOCKED_FILE
    powershell -NoProfile -Command "
      \$f = [IO.File]::Open('$VSQL_FILE.lock', 'OpenOrCreate', 'ReadWrite', 'ReadWrite');
      \$f.Lock(0, 1);
      Set-Content '$LOCKED_FILE' 'locked';
      Start-Sleep 2;
      Add-Content '$LOG_FILE' 'released';
      \$f.Close()" &
    i=0
    while [ ! -f $LOCKED_FILE ]; do
      i=$((i + 1))
      [ $i -lt 600 ] || exit 1
      sleep 0.1
    done
    ;;
  *)
    perl -e 'use Fcntl ":flock"; open(F, "<", $ARGV[0]) or die; flock(F, LOCK_EX);
      sleep 2; open(L, ">>", $ARGV[1]); print L "released\n"; close(L)' \
      $VSQL_FILE $LOG_FILE &
    sleep 1
    ;;
esac

echo 'INSERT INTO foo (bar) VALUES (123);' | $VSQL cli $VSQL_FILE
echo "inserted" >> $LOG_FILE
wait

cat $LOG_FILE
test "$(cat $LOG_FILE | tr -d '\r' | tr '\n' ' ')" = "released inserted "
