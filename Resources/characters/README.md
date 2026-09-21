# 도트 캐릭터 자산

인물별 폴더(`zhuge/`, `socrates/`, `nietzsche/`, `sejong/`)에 다음 파일을 넣으면 앱이 자동으로 사용합니다.
파일이 없으면 글만 표시됩니다(폴백).

| 파일 | 납품 크기 | 프레임 |
|---|---|---|
| `portrait.png` | 256×256 | 1 |
| `talking.png` | 768×256 | 3 |
| `writing.png` | 512×128 | 4 |
| `idle.png` | 256×128 | 2 |
| `menubar.png` | 36×36 | 1 (선택, 검은 실루엣) |
| `header.png` | 960×320 | 1 (선택, 편지 머리 배경 — 불투명) |
| `seal.png` | 256×256 | 1 (선택, 도트 인장 — 투명) |

자세한 규격과 제작 방법: [`docs/CODEX-REQUEST-characters.md`](../../docs/CODEX-REQUEST-characters.md), [`docs/CODEX-REQUEST-header-and-seals.md`](../../docs/CODEX-REQUEST-header-and-seals.md)
검증: `python3 scripts/check-characters.py --contact`
