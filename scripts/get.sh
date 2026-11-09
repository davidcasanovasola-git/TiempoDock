#!/bin/bash
# Instalador de TiempoDock en una línea:
#   curl -fsSL https://raw.githubusercontent.com/davidcasanovasola-git/TiempoDock/main/scripts/get.sh | bash
#
# Descarga la última versión publicada en GitHub Releases, comprueba su suma
# SHA-256 (y su certificación de origen si tienes `gh` instalado), la copia a
# Aplicaciones y la abre. No hace falta Xcode ni compilar nada.
set -euo pipefail

REPO="davidcasanovasola-git/TiempoDock"
BASE="https://github.com/${REPO}/releases/latest/download"
APP="TiempoDock.app"

say() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "TiempoDock solo funciona en macOS."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 13 ] || fail "TiempoDock necesita macOS 13 Ventura o posterior."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "→ Descargando la última versión de TiempoDock…"
curl -fsSL "${BASE}/TiempoDock.zip" -o "${TMP}/TiempoDock.zip" || fail "no se pudo descargar TiempoDock.zip"
curl -fsSL "${BASE}/TiempoDock.zip.sha256" -o "${TMP}/TiempoDock.zip.sha256" || fail "no se pudo descargar la suma SHA-256"

say "→ Comprobando la suma SHA-256…"
EXPECTED="$(awk '{print $1}' "${TMP}/TiempoDock.zip.sha256")"
ACTUAL="$(shasum -a 256 "${TMP}/TiempoDock.zip" | awk '{print $1}')"
[ "$EXPECTED" = "$ACTUAL" ] || fail "la suma SHA-256 no coincide; descarga corrupta o manipulada."

if command -v gh >/dev/null 2>&1; then
    say "→ Comprobando la certificación de origen con gh…"
    gh attestation verify "${TMP}/TiempoDock.zip" --repo "$REPO" >/dev/null \
        || fail "GitHub no certifica que este archivo lo haya generado el repositorio oficial."
fi

ditto -x -k "${TMP}/TiempoDock.zip" "$TMP"
[ -d "${TMP}/${APP}" ] || fail "el zip no contiene ${APP}"
codesign --verify --deep --strict "${TMP}/${APP}" || fail "la firma de la app no es válida."

if [ -w /Applications ]; then
    DEST_DIR="/Applications"
else
    DEST_DIR="${HOME}/Applications"
    mkdir -p "$DEST_DIR"
fi
DEST="${DEST_DIR}/${APP}"

if pgrep -x TiempoDock >/dev/null; then
    say "→ Cerrando la versión en marcha…"
    pkill -x TiempoDock || true
    sleep 1
fi

say "→ Instalando en ${DEST}…"
rm -rf "$DEST"
mv "${TMP}/${APP}" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${DEST}/Contents/Info.plist")"
open "$DEST"
say "✓ TiempoDock ${VERSION} instalado. A partir de ahora se actualiza solo."
