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

# The latest release redirects to its tag, such as .../releases/tag/v1.6.77.
version=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$repo/releases/latest")
version=${version##*/}
name=vsql-$version-$os-$arch

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $name.zip"
curl -fsSL -o "$tmp/$name.zip" "$repo/releases/download/$version/$name.zip"
unzip -q "$tmp/$name.zip" -d "$tmp"

mkdir -p "$dir"
mv "$tmp/$name/bin/vsql" "$dir/vsql"
chmod +x "$dir/vsql"
echo "Installed $dir/vsql ($version)"

case ":$PATH:" in
*":$dir:"*) ;;
*) echo "$dir isn't in your PATH, add it to run vsql" ;;
esac
