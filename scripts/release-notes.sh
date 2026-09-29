#!/bin/bash
# release-notes.sh — CHANGELOG.md에서 한 버전의 항목을 꺼내 표준 출력으로 낸다.
#   사용법: scripts/release-notes.sh 0.10.0 > /tmp/notes.md
#   해당 버전 항목이 없거나 비어 있으면 실패한다 — 릴리스 노트 없이 릴리스하지 않기 위함.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?버전을 주세요 (예: 0.10.0)}"
VERSION="${VERSION#v}"

NOTES="$(awk -v v="$VERSION" '
  /^## / { if (found) exit; if (index($0, "## " v " ") == 1 || $0 == "## " v) { found = 1; next } }
  found { print }
' "$ROOT/CHANGELOG.md" | sed -e '/./,$!d')"

if [[ -z "${NOTES//[[:space:]]/}" ]]; then
  echo "CHANGELOG.md에 '## $VERSION — 날짜' 항목이 없거나 비어 있습니다. 먼저 바뀐 점을 적으세요." >&2
  exit 1
fi
printf '%s\n' "$NOTES"
