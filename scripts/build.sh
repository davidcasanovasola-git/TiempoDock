#!/bin/bash
# Compila TiempoDock y genera build/TiempoDock.app
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="TiempoDock"
OUT="build/$APP_NAME.app"

# Binario universal: se compila para Apple (arm64) e Intel (x86_64) y se combinan.
ARCHS="${ARCHS:-arm64 x86_64}"
BINS=()
for ARCH in $ARCHS; do
    echo "→ Compilando para ${ARCH}…"
    swift build -c release --arch "$ARCH"
    BINS+=("$(swift build -c release --arch "$ARCH" --show-bin-path)/$APP_NAME")
done
# Binario de la arquitectura de este Mac, para generar el icono.
BIN="$(swift build -c release --arch "$(uname -m)" --show-bin-path)/$APP_NAME"

echo "→ Montando ${OUT}…"
rm -rf build
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
lipo -create "${BINS[@]}" -output "$OUT/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$OUT/Contents/Info.plist"
cp -R Resources/Localization/*.lproj "$OUT/Contents/Resources/"
mkdir -p "$OUT/Contents/Library/LaunchAgents"
cp Resources/io.github.tiempodock.agent.plist "$OUT/Contents/Library/LaunchAgents/"

# Versión: la variable VERSION, o si no la última etiqueta vX.Y.Z del repositorio.
if [ -z "${VERSION:-}" ]; then
    VERSION="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null | sed 's/^v//' || true)"
fi
if [ -n "${VERSION:-}" ]; then
    echo "→ Versión $VERSION"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$OUT/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$OUT/Contents/Info.plist"
fi

echo "→ Generando icono…"
"$BIN" --export-iconset build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$OUT/Contents/Resources/AppIcon.icns"
rm -rf build/AppIcon.iconset

echo "→ Firmando (firma local ad-hoc)…"
codesign --force --sign - "$OUT"

echo "✓ Listo: $OUT"
