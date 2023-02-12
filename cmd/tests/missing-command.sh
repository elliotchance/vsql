#!/bin/sh

set -e

$VSQL || exit 0

exit 1
