#!/bin/sh
# Собрать Isle и перезапустить последнюю сборку — чтобы сразу можно было потестировать.
set -e
cd "$(dirname "$0")/.."

# Перезапустить старые копии Isle и адаптер.
pkill -f "mediaremote-adapter.pl" 2>/dev/null || true
pkill -f "Isle.app/Contents/MacOS/Isle" 2>/dev/null || true

echo "Сборка…"
xcodebuild -scheme Isle -configuration Debug build >/dev/null 2>&1 || { echo "Ошибка сборки" >&2; exit 1; }

# Найти самый свежий билд (в build/ и в DerivedData).
app="$(find build "$HOME/Library/Developer/Xcode/DerivedData" -name "Isle.app" -type d 2>/dev/null | xargs ls -td 2>/dev/null | head -1)"

if [ -z "$app" ]; then
  echo "Билд Isle не найден" >&2
  exit 1
fi

echo "Запускаю: $app"
open "$app"
