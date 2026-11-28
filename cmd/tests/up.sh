#!/bin/sh

set -e

# "vsql up" (and install.sh) replace vsql with the latest release that has a
# zip. VSQL_RELEASES_API_URL points them at a fake list of releases on disk: v2
# is the newest, but its zips haven't been built yet, so v1 is used. The zip
# (for every platform) holds a copy of vsql with some bytes added, so the
# replacement can be told apart.

DIR="$(mktemp -d)" || exit 1
trap 'rm -rf "$DIR"' EXIT

EXE=vsql
case "$VSQL" in
*.exe) EXE=vsql.exe ;;
esac
mkdir "$DIR/bin"
cp "$VSQL" "$DIR/bin/$EXE"

# A build that isn't for a release is only replaced with -force. The build of
# a tag is a release (see set_version.sh), so it isn't refused. A build from git
# between releases has a version like v1.8.5-12-g1a2b3c4 (see build_version).
eval "$("$DIR/bin/$EXE" version -verbose)"
case "$VSQL_BUILD_VERSION" in
'' | *-*) NOT_RELEASE=1 ;;
*) NOT_RELEASE= ;;
esac
if [ -n "$NOT_RELEASE" ]; then
	if "$DIR/bin/$EXE" up > "$DIR/out.txt" 2>&1; then
		exit 1
	fi
	cat "$DIR/out.txt"
	grep -q 'not built for a release' "$DIR/out.txt"
fi

# zip isn't installed on Windows.
if ! command -v zip > /dev/null; then
	echo 'skipping the download, zip is not installed'
	exit 0
fi

RELEASES="$DIR/releases"
mkdir -p "$RELEASES/download/v1"
case "$RELEASES" in
/*) URL="file://$RELEASES" ;;
*) URL="file:///$RELEASES" ;;
esac
ASSETS=
for PLATFORM in linux-x86-64 linux-arm64 macos-x86-64 macos-arm64 windows-x86-64 windows-arm64; do
	NAME="vsql-v1-$PLATFORM"
	mkdir -p "$DIR/zip/$NAME/bin"
	cp "$VSQL" "$DIR/zip/$NAME/bin/$EXE"
	echo new >> "$DIR/zip/$NAME/bin/$EXE"
	(cd "$DIR/zip" && zip -qr "$RELEASES/download/v1/$NAME.zip" "$NAME")
	ASSETS="$ASSETS${ASSETS:+,}
      {
        \"name\": \"$NAME.zip\",
        \"browser_download_url\": \"$URL/download/v1/$NAME.zip\"
      }"
done
cat > "$RELEASES/releases.json" <<EOF
[
  {
    "tag_name": "v2",
    "assets": []
  },
  {
    "tag_name": "v1",
    "assets": [$ASSETS
    ]
  }
]
EOF
export VSQL_RELEASES_API_URL="$URL/releases.json"

"$DIR/bin/$EXE" up -force | tee "$DIR/out.txt"
grep -q 'Downloading vsql-v1-' "$DIR/out.txt"
cmp "$DIR/bin/$EXE" "$DIR/zip/vsql-v1-linux-x86-64/bin/$EXE"
test ! -e "$DIR/bin/$EXE.new"

# install.sh is only for Linux and macOS.
case $(uname -s) in
Linux | Darwin)
	VSQL_INSTALL_DIR="$DIR/install" sh install.sh | tee "$DIR/out.txt"
	grep -q '(v1)' "$DIR/out.txt"
	cmp "$DIR/install/vsql" "$DIR/zip/vsql-v1-linux-x86-64/bin/vsql"
	;;
esac

# A release that can't be downloaded.
rm "$RELEASES/download/v1/"*.zip
if "$DIR/bin/$EXE" up -force > "$DIR/out.txt" 2>&1; then
	exit 1
fi
cat "$DIR/out.txt"
grep -q 'cannot download' "$DIR/out.txt"

# No release has a zip yet.
printf '[{"tag_name": "v2", "assets": []}]' > "$RELEASES/releases.json"
if "$DIR/bin/$EXE" up -force > "$DIR/out.txt" 2>&1; then
	exit 1
fi
cat "$DIR/out.txt"
grep -q "no release with a zip" "$DIR/out.txt"
case $(uname -s) in
Linux | Darwin)
	if VSQL_INSTALL_DIR="$DIR/install" sh install.sh > "$DIR/out.txt" 2>&1; then
		exit 1
	fi
	cat "$DIR/out.txt"
	grep -q "no release with a zip" "$DIR/out.txt"
	;;
esac
