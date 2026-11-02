#!/bin/sh

set -e

# A whole run of speedtest1 takes minutes, even at -size 1, so only its options
# are tested here.
expect_error() {
  message=$1
  shift
  if output=$($VSQL bench "$@" 2>&1); then
    echo "expected an error from: bench $*"
    exit 1
  fi
  case "$output" in
    *"$message"*) ;;
    *)
      echo "$output"
      exit 1
      ;;
  esac
}

expect_error 'unknown suite: foo' -suite foo
expect_error '-size can only be used with -suite speedtest1' -size 1
expect_error '-size can only be used with -suite speedtest1' -suite tpcb -size 1
expect_error '-accounts cannot be used with -suite speedtest1' -suite speedtest1 -accounts 10
expect_error '-duration cannot be used with -suite speedtest1' -suite speedtest1 -duration 1
expect_error '-connections cannot be used with -suite speedtest1' -suite speedtest1 -connections 2
expect_error '-scale cannot be used with -suite speedtest1' -suite speedtest1 -scale 2

# Without -suite and with -suite tpcb it's the same benchmark.
$VSQL bench -file ':memory:' -accounts 10 -duration 1 | grep -q 'transactions/s'
$VSQL bench -suite tpcb -file ':memory:' -accounts 10 -duration 1 | grep -q 'transactions/s'
