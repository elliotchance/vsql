#!/bin/sh

# earlier-v.sh builds the newest of the 20 commits of V before the commit given
# (V master) that builds on Windows, and puts it on the PATH. It's only used
# when V master itself doesn't build on Windows (see ci.yml).

dir="$RUNNER_TEMP/v-earlier"
.github/workflows/retry.sh git clone -q --filter=blob:none https://github.com/vlang/v "$dir" || exit 1
cd "$dir" || exit 1

for commit in $(git rev-list --max-count=20 "$1^"); do
  git checkout -q "$commit" && git clean -qfdx
  # V renamed make.bat to makev.bat.
  bat=makev.bat
  [ -f "$bat" ] || bat=make.bat
  if cmd //c "$bat" && ./v.exe version; then
    echo "::warning::V master ($1) doesn't build on Windows, so this job uses $commit."
    echo "$dir" >> "$GITHUB_PATH"
    exit 0
  fi
done

echo "earlier-v.sh: none of the 20 commits before $1 build on Windows" >&2
exit 1
