#!/bin/bash
# Собирает MediaRemoteAdapter.framework (ungive/mediaremote-adapter) и кладёт
# его вместе со скриптом в Vendor/MediaRemoteAdapter. Результат лежит в git,
# поэтому запускать нужно только при обновлении версии. Нужен cmake (brew install cmake).
set -euo pipefail

VERSION="v0.8.0"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Vendor/MediaRemoteAdapter"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone -q --depth 1 --branch "$VERSION" https://github.com/ungive/mediaremote-adapter.git "$TMP/src"
cmake -S "$TMP/src" -B "$TMP/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 >/dev/null
cmake --build "$TMP/build" --target MediaRemoteAdapter >/dev/null

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$TMP/build/MediaRemoteAdapter.framework" "$OUT/"
cp "$TMP/src/bin/mediaremote-adapter.pl" "$OUT/"
cp "$TMP/src/LICENSE" "$OUT/LICENSE"
echo "$VERSION" > "$OUT/VERSION"
echo "Готово: $OUT ($VERSION)"
