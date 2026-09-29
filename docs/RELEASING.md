# 릴리스 절차

릴리스는 수동으로 한다(GitHub Actions 없음). **릴리스 노트는 `CHANGELOG.md`가 원본**이고, GitHub 릴리스 본문은 거기서 꺼내 쓴다. 0.8.0부터 앱의 새 버전 알림이 릴리스 페이지를 열기 때문에, 사용자가 보는 "바뀐 점"이 곧 이 노트다.

1. `CHANGELOG.md` 맨 위에 `## X.Y.Z — YYYY-MM-DD` 항목을 쓰고 커밋한다.
   - 사용자가 알아볼 말로 쓴다. 굵은 머리말 + 한 줄 설명, 고친 문제는 전에 어땠는지까지.
   - 항목이 없으면 `scripts/make-dmg.sh`가 멈춘다.
2. 태그: `git tag vX.Y.Z && git push origin main vX.Y.Z`
3. 빌드: `scripts/build-app.sh --version X.Y.Z` → `scripts/make-dmg.sh --version X.Y.Z`
4. 릴리스:
   ```bash
   scripts/release-notes.sh X.Y.Z > /tmp/notes.md
   gh release create vX.Y.Z dist/SageBar-X.Y.Z.dmg dist/SageBar-X.Y.Z.zip \
     --title "SageBar X.Y.Z — 한 줄 요약" --notes-file /tmp/notes.md
   ```
5. `homebrew-tap`의 `Casks/sagebar.rb` version·sha256 갱신 후 push.
6. `brew update && brew upgrade --cask sagebar`로 이 Mac 설치본 갱신, `dist/SageBar.app` 삭제.
