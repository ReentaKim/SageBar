#!/bin/bash
# make-dmg.sh — dist/SageBar.app을 Applications 바로가기가 든 dmg로 묶는다.
#   사용법: scripts/make-dmg.sh [--version 0.1.0]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${SAGEBAR_VERSION:-0.1.0}"
[[ "${1:-}" == "--version" ]] && VERSION="$2"
APP="$ROOT/dist/SageBar.app"
[[ -d "$APP" ]] || { echo "dist/SageBar.app이 없습니다. scripts/build-app.sh를 먼저 실행하세요." >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/dist/SageBar-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "SageBar" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
(cd "$ROOT/dist" && ditto -c -k --keepParent SageBar.app "SageBar-$VERSION.zip")
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "✔ $DMG"
