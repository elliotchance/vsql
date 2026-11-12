#!/bin/bash
# Only a tag is a release, anything else doesn't have a version.
case "$GITHUB_REF" in
  refs/tags/*) ;;
  *) exit 0 ;;
esac

# The backup suffix is required by BSD sed (macOS), which otherwise takes "-e"
# as the suffix and leaves a version.v-e file behind.
sed -i.bak -e "s/MISSING_VERSION/${GITHUB_REF##*/}/g" -e "s/MISSING_COMMIT/${GITHUB_SHA}/g" vsql/version.v
rm vsql/version.v.bak
