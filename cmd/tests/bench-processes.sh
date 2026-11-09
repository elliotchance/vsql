#!/bin/sh

# Several processes run transactions on the same file at the same time for 10
# seconds. Afterwards every balance must be the sum of its deltas in history, and
# history must have a row for each committed transaction (see "vsql bench
# -processes").

set -e

VSQL_FILE="$(mktemp).vsql" || exit 1

$VSQL bench -file $VSQL_FILE -accounts 1000 -duration 10 -processes 4
