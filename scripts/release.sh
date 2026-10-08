#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version, for example 0.1.0-alpha.1>}"
scripts/build-app.sh "${VERSION%%-*}"

rm -rf dist
mkdir -p dist
ditto -c -k --sequesterRsrc --keepParent build/Tabby.app dist/Tabby.zip
(cd dist && shasum -a 256 Tabby.zip > Tabby.zip.sha256)

awk -v version="$VERSION" '
    index($0, "## [" version "]") == 1 { printing = 1; next }
    printing && /^## \[/ { exit }
    printing { print }
' CHANGELOG.md > dist/release-notes.md
if [ ! -s dist/release-notes.md ]; then
    echo "Tabby $VERSION" > dist/release-notes.md
fi

echo "dist/Tabby.zip · sha256 $(cut -d' ' -f1 dist/Tabby.zip.sha256)"
