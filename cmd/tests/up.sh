#!/bin/sh

set -e

# "vsql up" replaces itself with the latest release. VSQL_RELEASES_URL points
# it at a fake release on disk, where "latest" doesn't redirect to a tag, so
# the version is "latest". The zip (for every platform) holds a copy of vsql
# with some bytes added, so the replacement can be told apart.

DIR="$(mktemp -d)" || exit 1
trap 'rm -rf "$DIR"' EXIT

EXE=vsql
case "$VSQL" in
*.exe) EXE=vsql.exe ;;
esac
mkdir "$DIR/bin"
cp "$VSQL" "$DIR/bin/$EXE"

# A build that isn't for a release is only replaced with -force.
if "$DIR/bin/$EXE" up > "$DIR/out.txt" 2>&1; then
	exit 1
fi
cat "$DIR/out.txt"
grep -q 'not built for a release' "$DIR/out.txt"

# zip isn't installed on Windows.
if ! command -v zip > /dev/null; then
	echo 'skipping the download, zip is not installed'
	exit 0
fi

RELEASES="$DIR/releases"
mkdir -p "$RELEASES/download/latest"
touch "$RELEASES/latest"
for PLATFORM in linux-x86-64 linux-arm64 macos-x86-64 macos-arm64 windows-x86-64 windows-arm64; do
	NAME="vsql-latest-$PLATFORM"
	mkdir -p "$DIR/zip/$NAME/bin"
	cp "$VSQL" "$DIR/zip/$NAME/bin/$EXE"
	echo new >> "$DIR/zip/$NAME/bin/$EXE"
	(cd "$DIR/zip" && zip -qr "$RELEASES/download/latest/$NAME.zip" "$NAME")
done

case "$RELEASES" in
/*) URL="file://$RELEASES" ;;
*) URL="file:///$RELEASES" ;;
esac
VSQL_RELEASES_URL="$URL" "$DIR/bin/$EXE" up -force
cmp "$DIR/bin/$EXE" "$DIR/zip/vsql-latest-linux-x86-64/bin/$EXE"
test ! -e "$DIR/bin/$EXE.new"

# A release that can't be downloaded.
rm "$RELEASES/download/latest/"*.zip
if VSQL_RELEASES_URL="$URL" "$DIR/bin/$EXE" up -force > "$DIR/out.txt" 2>&1; then
	exit 1
fi
cat "$DIR/out.txt"
grep -q 'cannot download' "$DIR/out.txt"
