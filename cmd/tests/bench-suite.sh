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
expect_error '-duration can not be used with -suite speedtest1' -suite speedtest1 -duration 1
expect_error '-size must be at least 1' -suite speedtest1 -size -1
expect_error 'unknown isolation level: foo' -suite speedtest1 -isolation foo
