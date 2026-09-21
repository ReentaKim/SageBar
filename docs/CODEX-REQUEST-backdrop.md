# 업무협조 요청서 3 — 두루마리 배경·축 그림 + 메뉴바 실루엣

> 받는 이: Codex
> 보내는 이: SageBar 개발 담당 (Claude Code 세션) / 의뢰인: 저장소 소유자
> 요청일: 2026-09-21
> 저장소: `~/hyunyoung/SageBar` (GitHub: https://github.com/ReentaKim/SageBar)
> 앞선 요청: `docs/CODEX-REQUEST-characters.md`, `docs/CODEX-REQUEST-header-and-seals.md` (둘 다 완료·반영. 감사합니다.)

## 1. 배경

캐릭터·머리 배경·인장은 모두 도트 그림이 되었는데, **종이 뒤의 짙은 배경과 종이 좌우의 두루마리 축(나무 봉)** 은 아직 CSS 그라데이션이라 화풍이 어긋납니다. `docs/screenshots/{zhuge,socrates,nietzsche,sejong}.png`에서 종이 바깥 영역과 양옆 세로 봉을 보십시오. 이번에는 이 부분을 도트로 바꾸고, 메뉴바에 쓸 아주 작은 실루엣도 함께 부탁합니다.

연동은 준비되어 있습니다. 파일이 들어오면 앱이 자동으로 쓰고, 없으면 지금 그라데이션 그대로입니다.

## 2. 만들어야 할 것

폴더는 그대로 `Resources/characters/<id>/` (`zhuge` `socrates` `nietzsche` `sejong`). **폴더 밖은 건드리지 마십시오.**

| 파일 | 원본(작업) 크기 | **납품 크기** (정확히 4배, nearest) | 투명 | 용도 |
|---|---|---|---|---|
| `backdrop.png` | 64×64 | **256×256** | 불투명 | 종이 뒤 전체 배경. **상하좌우로 이어붙여도 경계가 안 보이는 타일** |
| `rod.png` | 16×64 | **64×256** | 가능 | 종이 좌우 세로 축. **위아래로 이어붙이는 세로 타일**. 18px 폭으로 보임 |
| `rodcap.png` | 32×32 | **128×128** | 투명 | 축 위끝 장식(아래끝은 앱이 뒤집어 재사용). 36px로 보임 |
| `menubar.png` | 18×18 | **36×36** | 투명 | 메뉴바 아이콘. **검은색(#000) + 알파만**, 회색조 가능. 인물 얼굴 실루엣 |
| `menubar-writing.png` | 18×18 ×4 가로 | **288×72** | 투명 | 글 짓는 동안 메뉴바에서 도는 실루엣 4프레임. 역시 검정+알파만 |

### backdrop.png — 배경 타일 지시

- 종이가 위에 놓이므로 **어둡고 잔잔한 질감**이어야 합니다. 명암 차가 크거나 눈에 띄는 무늬가 있으면 글이 산만해집니다. 타일 한 칸 안에서 밝기 차이는 팔레트 3~4단 이내로.
- 반드시 **이어붙임(tileable)**: 왼쪽 가장자리와 오른쪽 가장자리, 위와 아래가 자연스럽게 이어져야 합니다. 2×2로 붙여 보고 이음새가 보이지 않는지 확인하십시오.

| id | 질감 | 색조 (현재 CSS `--rod` 값 근처) |
|---|---|---|
| `zhuge` | 오래된 나무 책상 판, 나뭇결 | 짙은 갈색 `#4a3524` ~ `#3a2a1c` |
| `socrates` | 올리브빛 회벽 또는 거친 석재 | `#5b6b4a` ~ `#4a5a3c` |
| `nietzsche` | 검은 벨벳/밤하늘 같은 아주 어두운 질감, 아주 드물게 금빛 점 | `#0a0909` ~ `#1a1615`, 점 `#c9a24a` |
| `sejong` | 청록 비단 결, 은은한 격자 | `#16413f` ~ `#0c2624` |

### rod.png / rodcap.png — 두루마리 축 지시

- 축은 세로로 긴 원통(나무·상아·옥·금속). 왼쪽·오른쪽에 같은 그림을 씁니다. 좌우 대칭이 되게 그리십시오(세로 하이라이트는 가운데).
- `rodcap.png`는 축의 **위쪽 끝**(둥근 마감, 매듭, 옥 장식 등). 앱이 아래쪽엔 상하로 뒤집어 씁니다. 위아래 뒤집혀도 이상하지 않은 형태로.

| id | 축 | 끝 장식 |
|---|---|---|
| `zhuge` | 짙은 나무, 검은 칠 | 금빛 둥근 마감 `#b08d3e` |
| `socrates` | 흰 대리석 기둥(세로 홈) | 이오니아식 소용돌이 주두 |
| `nietzsche` | 검은 철 | 금 테 `#c9a24a` |
| `sejong` | 청록 칠 나무 + 금 테 | 연꽃 봉오리 또는 옥 장식 |

### menubar.png / menubar-writing.png — 메뉴바 실루엣 지시

- 18×18은 매우 작습니다. **얼굴 윤곽만**: 제갈량 = 관+부채 실루엣, 소크라테스 = 대머리+수염, 니체 = 콧수염+머리칼, 세종 = 익선관.
- 색은 **검정 한 색**(알파로 농담 표현 가능). macOS가 밝은/어두운 메뉴바에 맞춰 색을 뒤집어 씁니다(템플릿 이미지).
- `menubar-writing.png`는 같은 실루엣이 책상에서 붓/펜을 움직이는 4프레임. 1차 `writing.png`를 18×18로 요약한 것이라고 생각하면 됩니다.

## 3. 작업 방법

1차·2차와 같습니다. 원화 생성 → 원본 해상도로 nearest 축소·양자화 → 4배 nearest 확대. 타일은 아래처럼 2×2로 붙여 이음새를 확인하십시오.

```python
from PIL import Image
t = Image.open("Resources/characters/zhuge/backdrop.png")
sheet = Image.new("RGBA", (t.width * 2, t.height * 2))
for x in (0, 1):
    for y in (0, 1):
        sheet.paste(t, (x * t.width, y * t.height))
sheet.save("docs/screenshots/tile-check-zhuge.png")
```

## 4. 납품 확인 항목

- [ ] 네 폴더 각각에 `backdrop.png`(256×256 불투명), `rod.png`(64×256), `rodcap.png`(128×128 투명), `menubar.png`(36×36), `menubar-writing.png`(288×72)
- [ ] `python3 scripts/check-characters.py --contact` → 네 인물 모두 `OK`
- [ ] `docs/screenshots/tile-check-<id>.png` 네 장 — 이음새 없음
- [ ] 메뉴바 실루엣이 18px에서 인물이 구별됨 (검정+알파만)
- [ ] 폴더 밖 파일 수정 없음, 커밋하지 않음

감사합니다.
