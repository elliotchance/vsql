#!/bin/sh

set -e

# A build from git prints its version from "git describe" (see build_version),
# but mainly we just want this test to make sure it accepts the version command.

$VSQL version
