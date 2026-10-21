#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="${HUHU_DIST:-$ROOT/dist}"
mkdir -p "$DIST/windows-x64"
cd "$ROOT/windows"
x86_64-w64-mingw32-windres -I. Huhu.rc -o "$DIST/windows-x64/Huhu.res.o"
x86_64-w64-mingw32-g++ -std=c++17 -O2 -Wall -Wextra -municode -mwindows \
  -static -static-libgcc -static-libstdc++ Huhu.cpp "$DIST/windows-x64/Huhu.res.o" \
  -o "$DIST/windows-x64/Huhu.exe" -lgdiplus -lole32 -lshlwapi -lshell32 -luser32 -lgdi32 -ladvapi32
makensis -V3 -DSOURCE_DIR="$ROOT" -DDIST_DIR="$DIST" installer.nsi
cp "$ROOT/README.md" "$ROOT/THIRD_PARTY_NOTICES.md" "$DIST/windows-x64/"
cp -R "$ROOT/licenses" "$DIST/windows-x64/"
(cd "$DIST/windows-x64" && 7zz a -tzip "$DIST/Huhu-1.2.1-windows-x64-portable.zip" Huhu.exe README.md THIRD_PARTY_NOTICES.md licenses >/dev/null)
printf 'Built Windows x64 executable and installer in %s\n' "$DIST"
