#!/bin/bash
# Compila TiempoDock, lo copia a /Applications y lo abre.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

DEST="/Applications/TiempoDock.app"
if pgrep -x TiempoDock >/dev/null; then
    echo "→ Cerrando la versión en marcha…"
    osascript -e 'quit app "TiempoDock"' || true
    sleep 1
    pkill -x TiempoDock || true
fi

echo "→ Instalando en $DEST…"
rm -rf "$DEST"
cp -R build/TiempoDock.app "$DEST"

echo "→ Abriendo…"
open "$DEST"
echo "✓ TiempoDock instalado."
