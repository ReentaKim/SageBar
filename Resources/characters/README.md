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
| `backdrop.png` | 256×256 | 1 (선택, 종이 뒤 배경 타일 — 불투명·이어붙임) |
| `rod.png` | 64×256 | 1 (선택, 두루마리 축 세로 타일) |
| `rodcap.png` | 128×128 | 1 (선택, 축 끝 장식 — 투명) |
| `menubar-writing.png` | 288×72 | 4 (선택, 메뉴바 글 쓰는 실루엣 — 검정+알파) |

자세한 규격과 제작 방법: [`docs/CODEX-REQUEST-characters.md`](../../docs/CODEX-REQUEST-characters.md), [`docs/CODEX-REQUEST-header-and-seals.md`](../../docs/CODEX-REQUEST-header-and-seals.md), [`docs/CODEX-REQUEST-backdrop.md`](../../docs/CODEX-REQUEST-backdrop.md)
검증: `python3 scripts/check-characters.py --contact`
