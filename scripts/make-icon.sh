#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE="${1:?usage: scripts/make-icon.sh <source.png>}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift scripts/make-icon.swift "$SOURCE" "$WORK/icon-1024.png"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET" App
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o App/AppIcon.icns
cp "$WORK/icon-1024.png" App/AppIcon-1024.png
echo "App/AppIcon.icns"
