#!/bin/bash
# Publica una versión nueva: ./scripts/release.sh 1.1.0
# Crea la etiqueta vX.Y.Z y la sube; GitHub Actions compila y publica el release.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Uso: ./scripts/release.sh X.Y.Z   (última: $(git describe --tags --abbrev=0 2>/dev/null || echo ninguna))"
    exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "Hay cambios sin guardar en git. Haz commit antes de publicar."
    exit 1
fi

git push origin HEAD
git tag "v$VERSION"
git push origin "v$VERSION"
echo "✓ Etiqueta v$VERSION subida. Sigue el progreso con: gh run watch"
