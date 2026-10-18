#!/bin/bash
# The backup suffix is required by BSD sed (macOS), which otherwise takes "-e"
# as the suffix and leaves a version.v-e file behind.
sed -i.bak -e "s/MISSING_VERSION/${GITHUB_REF##*/} `date +'%F'`/g" cmd/vsql-cli/version.v
rm cmd/vsql-cli/version.v.bak
