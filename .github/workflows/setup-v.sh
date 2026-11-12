#!/bin/bash

# setup-v.sh builds V and puts it on the PATH. It's given a commit of vlang/vc
# (V master if it's left out), which is the generated C that V is built from,
# and builds the commit of V that it was generated from.
#
# V's build pulls the newest vc, whichever V is being built, so a broken vc
# breaks every build of V, even of commits that used to build. Instead, vc's
# master is kept at the commit given, and is its own upstream, so the pull does
# nothing. (origin can't change, since the blobs of a clone with --filter are
# fetched from it when they're needed.)
#
# If that commit doesn't build here, the newest of the commits before it that
# does is used instead, with a warning. vc is only pushed by V's CI, but V's
# own CI on master is almost always cancelled by the next push, so whether a
# commit builds is the only way to tell.
#
# V is in ~/vlang (or $V_DIR).

dir="${V_DIR:-$HOME/vlang}"
tries=10
retry=.github/workflows/retry.sh

rm -rf "$dir"
$retry git clone -q --filter=blob:none https://github.com/vlang/v "$dir" || exit 1
$retry git clone -q --filter=blob:none https://github.com/vlang/vc "$dir/vc" || exit 1
git -C "$dir/vc" config branch.master.remote .
git -C "$dir/vc" config branch.master.merge refs/heads/master

first=${1:-$(git -C "$dir/vc" rev-parse HEAD)}

exe=
[ "$RUNNER_OS" = Windows ] && exe=.exe

build() {
  if [ "$RUNNER_OS" = Windows ]; then
    # V renamed make.bat to makev.bat. MSVC is tried first, then GCC, like
    # vlang/setup-v.
    bat=makev.bat
    [ -f "$dir/$bat" ] || bat=make.bat
    (cd "$dir" && { cmd //c "$bat" || cmd //c "$bat -gcc"; })
  else
    (cd "$dir" && make)
  fi
}

for vc in $(git -C "$dir/vc" rev-list --max-count=$tries "$first"); do
  # Each vc commit is titled "[v:master] <commit of V> - <title of V's commit>".
  v=$(git -C "$dir/vc" log -1 --format=%s "$vc" | sed -n 's/^\[v:master\] \([0-9a-f]\{40\}\) .*/\1/p')
  [ -n "$v" ] || continue

  git -C "$dir/vc" checkout -q -B master "$vc" || exit 1
  git -C "$dir" checkout -q -f "$v" || exit 1
  git -C "$dir" clean -qfdx -e /vc/

  # The first commit is built twice before giving up on it, since a build
  # sometimes fails for reasons that have nothing to do with V (such as
  # downloading TCC).
  if build || { [ "$vc" = "$first" ] && build; }; then
    if "$dir/v$exe" version; then
      if [ "$vc" != "$first" ]; then
        echo "::warning::V from vc $first doesn't build here, so this job uses V $v (vc $vc)."
      fi
      # On Windows, the PATH needs C:\... rather than Git Bash's /c/...,
      # since make runs simple commands (such as "v fmt") without a shell.
      if [ "$RUNNER_OS" = Windows ]; then
        cygpath -w "$dir" >> "$GITHUB_PATH"
      else
        echo "$dir" >> "$GITHUB_PATH"
      fi
      exit 0
    fi
  fi
done

echo "setup-v.sh: none of the $tries vc commits from $first build here" >&2
exit 1
