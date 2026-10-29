#!/bin/sh

# retry.sh runs a command up to 3 times, waiting longer after each failure. It's
# for the steps that use the network (such as installing packages or uploading
# to the release), which sometimes fail for reasons that have nothing to do with
# vsql.

for attempt in 1 2 3; do
  "$@" && exit 0
  if [ $attempt -lt 3 ]; then
    echo "retry.sh: attempt $attempt of 3 failed, retrying in $((attempt * 15))s: $*" >&2
    sleep $((attempt * 15))
  fi
done

echo "retry.sh: all 3 attempts failed: $*" >&2
exit 1
