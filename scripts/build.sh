#!/bin/bash
# Compila TiempoDock y genera build/TiempoDock.app
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="TiempoDock"
OUT="build/$APP_NAME.app"

echo "→ Compilando…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "→ Montando $OUT…"
rm -rf build
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$OUT/Contents/Info.plist"

echo "→ Generando icono…"
"$BIN" --export-iconset build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$OUT/Contents/Resources/AppIcon.icns"
rm -rf build/AppIcon.iconset

echo "→ Firmando (firma local ad-hoc)…"
codesign --force --sign - "$OUT"

echo "✓ Listo: $OUT"
