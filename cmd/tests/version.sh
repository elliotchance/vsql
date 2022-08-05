#!/bin/sh

set -e

# This should print out "no version information available" which isn't that
# helpful. But mainly we just want this test to make sure it accepts the version
# command.

$VSQL version
