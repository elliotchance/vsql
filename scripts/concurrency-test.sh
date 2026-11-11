#!/bin/sh

# concurrency-test runs "vsql bench" on one file from several processes at the
# same time (see "Concurrency" in docs/testing.rst):
#
# 1. tpc-b-setup.
# 2. CONNECTIONS tpc-b-oltp processes at SERIALIZABLE for DURATION seconds.
# 3. tpc-b-check. No transaction may fail with a serialization failure, since
#    they take turns.
# 4. CONNECTIONS tpc-b-oltp processes at READ COMMITTED for DURATION seconds.
# 5. tpc-b-check. Serialization failures are allowed (they write the same
#    rows), up to MAX_FAILURE_PERCENT of the transactions.
#
# Each check also fails if HISTORY doesn't have exactly one row for each
# transaction that was committed.

set -e

VSQL=${VSQL:-bin/vsql}
CONNECTIONS=${CONNECTIONS:-10}
DURATION=${DURATION:-5}
MAX_FAILURE_PERCENT=${MAX_FAILURE_PERCENT:-90}

dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
file="$dir/bench.vsql"

value() {
  grep "^$1=" "$2" | cut -d= -f2
}

# committed is the total of every round, which HISTORY must have a row for each
# of.
committed=0

# round runs CONNECTIONS processes at the isolation level $1 at the same time,
# and sets round_committed and round_failures.
round() {
  echo "# $1"
  pids=""
  i=1
  while [ $i -le $CONNECTIONS ]; do
    $VSQL bench -file "$file" -suite tpc-b-oltp -duration "$DURATION" \
      -isolation "$1" > "$dir/$1-$i.out" 2>&1 &
    pids="$pids $!"
    i=$((i + 1))
  done

  # Each process is waited for, so that one that fails doesn't leave the
  # others running.
  failed=0
  i=1
  for pid in $pids; do
    if ! wait "$pid"; then
      echo "connection $i failed:"
      cat "$dir/$1-$i.out"
      failed=1
    fi
    i=$((i + 1))
  done
  if [ $failed -ne 0 ]; then
    exit 1
  fi

  round_committed=0
  round_failures=0
  i=1
  while [ $i -le $CONNECTIONS ]; do
    transactions=$(value transactions "$dir/$1-$i.out")
    failures=$(value serialization_failures "$dir/$1-$i.out")
    echo "connection $i: $transactions committed, $failures serialization failures"
    round_committed=$((round_committed + transactions))
    round_failures=$((round_failures + failures))
    i=$((i + 1))
  done
  echo "total: $round_committed committed, $round_failures serialization failures"

  if [ $round_committed -eq 0 ]; then
    echo "no transactions were committed"
    exit 1
  fi
  committed=$((committed + round_committed))
}

# check runs tpc-b-check, which checks the balances, and that HISTORY has a row
# for each transaction that was committed.
check() {
  $VSQL bench -file "$file" -suite tpc-b-check > "$dir/check.out"
  history=$(value check_history_rows "$dir/check.out")
  if [ "$history" != "$committed" ]; then
    echo "TPC_B.HISTORY has $history rows, expected $committed (one for each committed transaction)"
    exit 1
  fi
  echo "check passed: $committed transactions"
}

$VSQL bench -file "$file" -suite tpc-b-setup > "$dir/setup.out"

round serializable
if [ $round_failures -ne 0 ]; then
  echo "SERIALIZABLE transactions take turns, so none should fail"
  exit 1
fi
check

round read-committed
percent=$((round_failures * 100 / (round_committed + round_failures)))
echo "$percent% of the transactions failed"
if [ $percent -gt "$MAX_FAILURE_PERCENT" ]; then
  echo "more than $MAX_FAILURE_PERCENT% of the transactions failed"
  exit 1
fi
check
