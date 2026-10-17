#!/bin/bash
sed -i -e "s/MISSING_VERSION/${GITHUB_REF##*/} `date +'%F'`/g" cmd/vsql-cli/version.v
