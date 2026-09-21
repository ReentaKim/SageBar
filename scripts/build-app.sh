#!/bin/bash
# build-app.sh — SwiftPM으로 릴리스 빌드 후 SageBar.app 번들을 조립하고 ad-hoc 서명한다.
#   사용법: scripts/build-app.sh [--version 0.1.0] [--single-arch]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${SAGEBAR_VERSION:-0.1.0}"
SINGLE_ARCH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --single-arch) SINGLE_ARCH=1; shift ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done
BUILD_NUM="$(date +%Y%m%d%H%M)"

echo "▶ swift build (release, version $VERSION)"
if [[ "$SINGLE_ARCH" -eq 1 ]]; then
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/SageBar"
else
  swift build -c release --arch arm64 --arch x86_64
  BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/SageBar"
fi

APP="$ROOT/dist/SageBar.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SageBar"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUM/" scripts/Info.plist > "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
cp -R "$ROOT/Resources/." "$APP/Contents/Resources/"

echo "▶ codesign (ad-hoc)"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP" && echo "✔ $APP"
