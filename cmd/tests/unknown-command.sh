#!/bin/sh

set -e

$VSQL no-such-command || exit 0

exit 1
