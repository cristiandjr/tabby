#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
BUILD="${2:-$(date +%Y%m%d%H%M)}"
IDENTITY="${TABBY_SIGNING_IDENTITY:-Tabby Code Signing}"
PACKAGE="Packages/TabbyKit"
APP="build/Tabby.app"

UNIVERSAL=(--arch arm64 --arch x86_64)
if ! swift build --package-path "$PACKAGE" -c release --product Tabby "${UNIVERSAL[@]}"; then
    echo "warning: universal build failed, building for this Mac only"
    UNIVERSAL=()
    swift build --package-path "$PACKAGE" -c release --product Tabby
fi
BINARY="$(swift build --package-path "$PACKAGE" -c release --product Tabby ${UNIVERSAL[@]+"${UNIVERSAL[@]}"} --show-bin-path)/Tabby"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Tabby"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" App/Info.plist > "$APP/Contents/Info.plist"
cp App/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp docs/assets/logo-dark.png "$APP/Contents/Resources/Logo-dark.png"
cp docs/assets/logo-light.png "$APP/Contents/Resources/Logo-light.png"

if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --options runtime --sign "$IDENTITY" "$APP"
else
    echo "warning: signing identity \"$IDENTITY\" not found, signing ad hoc (Accessibility must be granted again after every build)"
    codesign --force --options runtime --sign - "$APP"
fi

codesign --verify --strict "$APP"
echo "Built $APP ($VERSION, build $BUILD, $(lipo -archs "$APP/Contents/MacOS/Tabby"))"
