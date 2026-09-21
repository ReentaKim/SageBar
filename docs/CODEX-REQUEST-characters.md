# 업무협조 요청서 — SageBar 도트 캐릭터 제작

> 받는 이: Codex
> 보내는 이: SageBar 개발 담당 (Claude Code 세션) / 의뢰인: 저장소 소유자
> 요청일: 2026-09-21
> 저장소: `~/hyunyoung/SageBar` (GitHub: https://github.com/ReentaKim/SageBar)

## 1. 프로젝트가 무엇인가

**SageBar**는 macOS 메뉴바 앱입니다. 제갈량·소크라테스·니체·세종대왕 네 현자가 하루씩 돌아가며, 사용자가 Claude Code와 나눈 대화 기록을 읽고 아침마다 조언 편지를 씁니다. 편지는 인물마다 다른 테마(한지 두루마리 / 대리석 / 검은 종이와 금박 / 청록 비단)의 HTML 화면으로 뜹니다.

지금은 **글만** 나옵니다. 이번 요청은 네 인물의 **도트(픽셀 아트) 캐릭터**를 만들어

1. 글을 짓는 동안 뜨는 대기 화면에 "책상에서 글 쓰는 모습" 애니메이션을,
2. 완성된 편지 머리에 "말하는 듯한" 얼굴 애니메이션을

넣기 위한 것입니다. **그림 파일만** 만들어 주시면 됩니다. 코드·CSS 연동은 이쪽에서 이미 준비해 두었고, 아래 규격의 파일이 지정 폴더에 들어오면 바로 화면에 나타납니다.

### 먼저 읽어 보면 좋은 파일 (톤 맞추기용, 수정 금지)

| 파일 | 무엇이 있나 |
|---|---|
| `Sources/SageBar/Model/Persona.swift` | 네 인물의 성격·말투·글 이름 정의. 캐릭터 인상을 잡을 때 참고 |
| `Resources/styles/persona-*.css` | 인물별 테마 색상 변수 (`--hanji`, `--vermilion`, `--gold` 등) |
| `Resources/seals/*.svg` | 인물별 인장. 편지 오른쪽 아래에 찍힘 |
| `docs/screenshots/*.png` | 현재 편지 화면. 캐릭터가 놓일 자리를 상상할 때 |
| `Resources/templates/letter.html`, `waiting.html` | 캐릭터가 들어갈 자리(`sage-avatar`, `sage-sprite`)가 이미 있음 |

## 2. 만들어야 할 것

### 스타일

- **삼국지 조조전(코에이, 1998)** 의 감성. 64×64 얼굴 초상 + 32×32 필드 스프라이트라는 **두 크기를 용도별로** 씁니다. 의뢰인이 예시 이미지를 줄 수 있으니 요청하십시오.
- 굵은 외곽선, 명암 2~3단, 인물당 **팔레트 16색 안팎**으로 통일. 안티에일리어싱 없음(딱딱한 픽셀 경계).
- 배경 **완전 투명**. 이미지 안에 **글자 없음**.
- 시점: 초상·말하는 컷은 정면 또는 약간 좌향 3/4. 글 쓰는 컷은 **책상 앞에 앉아 좌향**, 붓/펜을 든 손이 움직임.
- 프레임 간에는 **캐릭터 위치·크기가 정확히 같고**, 움직이는 부분(입, 손, 몸의 미세한 상하)만 바뀝니다.

### 저장 위치와 파일 규격

폴더: `Resources/characters/<id>/` — `<id>`는 `zhuge`, `socrates`, `nietzsche`, `sejong` 네 개. **이 폴더 밖의 파일은 만들거나 고치지 마십시오.**

| 파일 | 원본(작업) 크기 | **납품 크기** (원본의 정확히 4배, nearest neighbor) | 프레임 | 용도 |
|---|---|---|---|---|
| `portrait.png` | 64×64 | **256×256** | 1 | 편지 머리, 지난 글 목록, README |
| `talking.png` | 64×64 ×3 가로 나열 | **768×256** | 3: 입 닫힘 → 반쯤 → 열림 | 편지 머리 "말하는" 애니메이션 (1→2→3→2 순환) |
| `writing.png` | 32×32 ×4 가로 나열 | **512×128** | 4: 붓/펜을 드는 동작 한 순환 | 대기 화면 "글 짓는 중" |
| `idle.png` | 32×32 ×2 가로 나열 | **256×128** | 2: 숨쉬기(몸 1px 상하) | 대기 끝·실패 화면 |
| `menubar.png` | 18×18 | **36×36** | 1 | 메뉴바 아이콘. **검은 실루엣 + 알파만** (색 없음). 선택 사항 |

- 형식: PNG, **RGBA**.
- `talking.png`의 1번 프레임은 `portrait.png`와 같은 그림이어야 합니다(입만 닫힌 상태).
- 4배 확대는 **보간 없이**(nearest) 해서 픽셀이 뭉개지지 않게 합니다. 검증 스크립트가 이를 확인합니다.

### 인물별 지시

| id | 인물 | 외형 | 소품·표정 | 팔레트(테마와 맞춤) |
|---|---|---|---|---|
| `zhuge` | 제갈량 (촉한 승상, 중년) | 관(모자)을 쓰고 푸른 도포, 짧은 수염 | 흰 깃털 부채. 차분하고 날카로운 눈 | 한지 `#f2e8d5`, 주홍 `#9b2226`, 먹 `#1c1917`, 나무 `#4a3524`, 도포 청색 계열 |
| `socrates` | 소크라테스 (노년) | 대머리, 덥수룩한 흰 수염, 둥근 코, 토가 | 글 쓰는 컷은 파피루스와 갈대펜. 장난스러운 미소 | 대리석 `#f4f1ea`, 올리브 `#5b6b4a`, 테라코타 `#b5532a` |
| `nietzsche` | 니체 (중년) | 큼직한 콧수염, 높은 옷깃의 검은 코트, 뒤로 넘긴 머리 | 글 쓰는 컷은 펜과 노트. 찌르는 눈빛, 무표정 | 검정 `#151312`, 금 `#c9a24a`, 붉은 `#c8322e`, 종이 `#ece4d4` |
| `sejong` | 세종대왕 (중년) | 익선관(검은 모자), 붉은 곤룡포(용 무늬 생략 가능), 둥근 얼굴 | 글 쓰는 컷은 붓과 한지. 온화한 미소 | 청록 `#1f6f6b`, 금 `#c39a3b`, 비단 `#f3ecd9`, 곤룡포 적색 |

## 3. 권하는 작업 방법

이미지 생성 모델은 "3프레임을 정확한 격자에 배치한 스프라이트 시트"를 한 번에 잘 만들지 못합니다. 아래 순서를 권합니다.

1. **초상 원화 1장** — 인물별로 정면 초상을 생성합니다(큰 해상도라도 좋음). 이것이 캐릭터의 기준입니다.
2. **프레임을 한 장씩** — 같은 프롬프트 + "입을 반쯤 벌림", "입을 벌림"처럼 바뀌는 부분만 바꿔 생성합니다. 글 쓰는 컷도 4장, 숨쉬기 2장을 각각.
3. **원본 해상도로 정리** — 각 장을 64×64(또는 32×32)로 nearest 축소하고 16색 안팎으로 양자화합니다. 배경은 투명하게 지웁니다(`Image.quantize`, 배경색 → 알파 0).
4. **Pillow로 시트 조립** — 프레임을 가로로 붙이고, 마지막에 **4배 nearest 확대**해 납품 크기로 저장합니다.
5. **검증** — `python3 scripts/check-characters.py --contact` 가 네 인물 모두 `OK`를 출력해야 합니다. `docs/screenshots/characters-contact.png`에 모아보기가 저장됩니다.

조립 스크립트 골격(참고용):

```python
from PIL import Image

def to_pixel(path, size, colors=16):
    im = Image.open(path).convert("RGBA")
    im = im.resize((size, size), Image.NEAREST)
    rgb = im.convert("RGB").quantize(colors=colors).convert("RGBA")
    rgb.putalpha(im.split()[-1])          # 원래 알파 유지
    return rgb

def sheet(frames, size, out, scale=4):
    s = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * size, 0))
    s.resize((s.width * scale, s.height * scale), Image.NEAREST).save(out)

# 예: 제갈량 말하는 컷
frames = [to_pixel(f"work/zhuge_talk_{i}.png", 64) for i in (1, 2, 3)]
sheet(frames, 64, "Resources/characters/zhuge/talking.png")
sheet(frames[:1], 64, "Resources/characters/zhuge/portrait.png")
```

## 4. 납품 확인 항목

- [ ] `Resources/characters/{zhuge,socrates,nietzsche,sejong}/` 에 `portrait.png`, `talking.png`, `writing.png`, `idle.png` (선택: `menubar.png`)
- [ ] `python3 scripts/check-characters.py --contact` → 네 인물 모두 `OK`, `결과: 전부 OK`
- [ ] `docs/screenshots/characters-contact.png` 생성
- [ ] 네 인물이 **같은 화풍**(외곽선 굵기, 명암 단계, 픽셀 밀도)으로 보임
- [ ] 프레임을 겹쳐 보았을 때 캐릭터 위치가 흔들리지 않음
- [ ] 이 폴더 밖의 파일(Swift, CSS, HTML, README)은 건드리지 않음
- [ ] 커밋은 하지 않고 파일만 남겨 둠 (검토 후 이쪽에서 커밋)

## 5. 궁금한 점이 생기면

- 인물의 인상이나 소품이 애매하면 `Sources/SageBar/Model/Persona.swift`의 `voiceGuide`를 읽고 그 성격에 맞게 판단해도 됩니다.
- 조조전 예시 이미지가 필요하면 의뢰인에게 요청하십시오.
- 규격표와 다르게 만들고 싶은 이유가 있으면(예: 말하는 컷 프레임을 4개로), 만들기 전에 의뢰인에게 알려 주십시오. 연동 코드는 위 규격에 맞춰져 있습니다.

감사합니다.
