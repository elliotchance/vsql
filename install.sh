#!/bin/sh
# install.sh installs the vsql command from the latest release on Linux or
# macOS (see docs/install.rst):
#
#   curl -fsSL https://raw.githubusercontent.com/elliotchance/vsql/main/install.sh | sh
#
# It's installed in ~/.local/bin, or VSQL_INSTALL_DIR if it's set. "vsql up"
# updates it to the latest release.

set -eu

repo=https://github.com/elliotchance/vsql
dir=${VSQL_INSTALL_DIR:-$HOME/.local/bin}

case $(uname -s) in
Linux) os=linux ;;
Darwin) os=macos ;;
*)
	echo "There's no install script for $(uname -s), download the zip from $repo/releases/latest" >&2
	exit 1
	;;
esac

case $(uname -m) in
x86_64 | amd64) arch=x86-64 ;;
arm64 | aarch64) arch=arm64 ;;
*)
	echo "There's no prebuilt binary for $(uname -m), see https://vsql.readthedocs.io/en/latest/install.html" >&2
	exit 1
	;;
esac

for command in curl unzip; do
	if ! command -v $command >/dev/null; then
		echo "$command must be installed first" >&2
		exit 1
	fi
done

# A release is published as soon as its tag is pushed, and its zips are added
# when they're built (which can take a while, or fail), so the latest release
# may not have one yet. The releases are newest first, so it's the first zip
# for this OS and CPU, such as .../download/v1.6.77/vsql-v1.6.77-macos-arm64.zip.
# VSQL_RELEASES_API_URL replaces the GitHub API for the tests (see
# cmd/tests/up.sh).
api=${VSQL_RELEASES_API_URL:-https://api.github.com/repos/elliotchance/vsql/releases?per_page=100}
releases=$(curl -fsSL "$api")
url=$(printf '%s\n' "$releases" | grep -o '"browser_download_url": *"[^"]*/vsql-[^"/]*-'"$os-$arch"'\.zip"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/') || true
if [ -z "$url" ]; then
	echo "There's no release with a zip for $os-$arch yet, see $repo/releases" >&2
	exit 1
fi
version=${url%/*}
version=${version##*/}
name=vsql-$version-$os-$arch

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $name.zip"
curl -fsSL -o "$tmp/$name.zip" "$url"
unzip -q "$tmp/$name.zip" -d "$tmp"

mkdir -p "$dir"
mv "$tmp/$name/bin/vsql" "$dir/vsql"
chmod +x "$dir/vsql"
echo "Installed $dir/vsql ($version)"

case ":$PATH:" in
*":$dir:"*) ;;
*) echo "$dir isn't in your PATH, add it to run vsql" ;;
esac
