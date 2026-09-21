#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check-characters.py — Resources/characters/<id>/ 의 도트 캐릭터 자산이 규격에 맞는지 검사한다.

    python3 scripts/check-characters.py            # 전체 검사
    python3 scripts/check-characters.py --contact  # 검사 + docs/screenshots/characters-contact.png 생성

규격 (납품 크기 = 원본의 4배, nearest neighbor):
    portrait.png   256x256   1프레임
    talking.png    768x256   3프레임(가로)
    writing.png    512x128   4프레임(가로)
    idle.png       256x128   2프레임(가로)
    menubar.png    36x36     1프레임 (선택)
    header.png     960x320   1프레임 (선택) — 편지 머리 배경
    seal.png       256x256   1프레임 (선택) — 도트 인장
공통: PNG RGBA, 배경 투명, 각 프레임에 실제 내용이 있음, 4배 확대가 정확할 것(2x2 픽셀 블록이 균일).
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("Pillow가 필요합니다: python3 -m pip install pillow")
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR_DIR = os.path.join(ROOT, "Resources", "characters")
IDS = ["zhuge", "socrates", "nietzsche", "sejong"]

SPEC = {
    # 파일: (납품 가로, 납품 세로, 프레임 수, 필수 여부)
    "portrait.png": (256, 256, 1, True),
    "talking.png": (768, 256, 3, True),
    "writing.png": (512, 128, 4, True),
    "idle.png": (256, 128, 2, True),
    "menubar.png": (36, 36, 1, False),
    "header.png": (960, 320, 1, False),    # 편지 머리 배경 그림 (240×80 원본)
    "seal.png": (256, 256, 1, False),      # 도트 인장 (64×64 원본)
    "backdrop.png": (256, 256, 1, False),  # 종이 뒤 배경 타일 (64×64 원본, 불투명, 이어붙임 가능)
    "rod.png": (64, 256, 1, False),        # 두루마리 축 세로 타일 (16×64 원본, 투명 가능)
    "rodcap.png": (128, 128, 1, False),    # 축 끝 장식 (32×32 원본, 투명)
    "menubar-writing.png": (288, 72, 4, False),  # 메뉴바용 글 쓰는 실루엣 4프레임 (18×18 ×4 원본, 검정+알파)
    "reaction-pleased.png": (256, 256, 1, False),  # 점검 상자 표정: 대체로 했다 (64×64)
    "reaction-stern.png": (256, 256, 1, False),    # 점검 상자 표정: 대체로 안 했다 (64×64)
}
UI_DESK_DIR = os.path.join(ROOT, "Resources", "ui", "desk")
UI_DESK_SPEC = {   # 「현자의 서재」 장면 (요청서 5)
    "desk-bg.png": (960, 600, 1, False),
    "sky-morning.png": (160, 120, 1, False), "sky-day.png": (160, 120, 1, False),
    "sky-evening.png": (160, 120, 1, False), "sky-night.png": (160, 120, 1, False),
    "scroll-zhuge.png": (128, 56, 1, False), "scroll-socrates.png": (128, 56, 1, False),
    "scroll-nietzsche.png": (128, 56, 1, False), "scroll-sejong.png": (128, 56, 1, False),
    "scroll-blank.png": (128, 56, 1, False),
    "bundle.png": (112, 96, 1, False), "bundle-open.png": (112, 96, 1, False),
    "lamp.png": (128, 96, 2, False),
    "ledger.png": (272, 288, 1, False), "menu-panel.png": (272, 240, 1, False),
    "menu-today.png": (64, 64, 1, False), "menu-new.png": (64, 64, 1, False),
    "menu-profile.png": (64, 64, 1, False), "menu-settings.png": (64, 64, 1, False),
}
UI_DIR = os.path.join(ROOT, "Resources", "ui")
UI_SPEC = {   # 인물 공통 UI 아이콘 (Resources/ui/)
    "fb-sharp.png": (96, 96, 1, False),    # 찔렸다 아이콘 (24×24 원본)
    "fb-dull.png": (96, 96, 1, False),     # 뻔했다 아이콘 (24×24 원본)
    "fb-miss.png": (96, 96, 1, False),     # 내 얘기와 달랐다 아이콘 (24×24 원본)
    "fb-stamp.png": (128, 128, 1, False),  # 반응 남긴 뒤 찍히는 "새김" 도장 (32×32 원본)
}
OPAQUE = {"header.png", "backdrop.png", "desk-bg.png", "sky-morning.png", "sky-day.png", "sky-evening.png", "sky-night.png"}   # 꽉 채운 그림이어야 하는 것
SCALE = 4


def check_scale_blocks(im, scale=SCALE):
    """정확히 scale배 nearest 확대인지 — 각 scale×scale 블록이 단색인지 표본 검사."""
    px = im.load()
    w, h = im.size
    bad = 0
    total = 0
    for by in range(0, h, scale * 7):        # 표본 추출 (전부 보면 느리다)
        for bx in range(0, w, scale * 7):
            base = px[bx, by]
            total += 1
            for dy in range(scale):
                for dx in range(scale):
                    if px[bx + dx, by + dy] != base:
                        bad += 1
                        break
                else:
                    continue
                break
    return bad, total


def frame_has_content(im, frame_w, i):
    frame = im.crop((i * frame_w, 0, (i + 1) * frame_w, im.size[1]))
    alpha = frame.split()[-1]
    return alpha.getbbox() is not None


def check_dir(d, spec):
    problems = []
    for name, (w, h, frames, required) in spec.items():
        p = os.path.join(d, name)
        if not os.path.exists(p):
            if required:
                problems.append(f"{name}: 없음")
            continue
        try:
            im = Image.open(p)
        except Exception as e:  # noqa
            problems.append(f"{name}: 열 수 없음 ({e})")
            continue
        if im.format != "PNG":
            problems.append(f"{name}: PNG가 아님 ({im.format})")
        if im.mode != "RGBA":
            problems.append(f"{name}: RGBA가 아님 ({im.mode}) — 투명 배경 필요")
            im = im.convert("RGBA")
        if im.size != (w, h):
            problems.append(f"{name}: 크기 {im.size[0]}x{im.size[1]} (기대 {w}x{h})")
            continue
        alpha = im.split()[-1]
        corners = [alpha.getpixel((0, 0)), alpha.getpixel((w - 1, 0)), alpha.getpixel((0, h - 1)), alpha.getpixel((w - 1, h - 1))]
        if name in OPAQUE:
            # 배경 그림은 꽉 채운 장면이어야 한다
            if any(c < 250 for c in corners):
                problems.append(f"{name}: 모서리가 투명 — 배경 그림은 불투명하게 꽉 채울 것")
        elif any(c > 8 for c in corners):
            # 나머지는 네 모서리가 투명해야 배경이 뚫린 것
            problems.append(f"{name}: 모서리가 불투명 — 배경이 투명하지 않음")
        frame_w = w // frames
        for i in range(frames):
            if not frame_has_content(im, frame_w, i):
                problems.append(f"{name}: {i + 1}번째 프레임이 비어 있음")
        bad, total = check_scale_blocks(im)
        if total and bad / total > 0.05:
            problems.append(f"{name}: {SCALE}배 nearest 확대가 아닌 듯함 (블록 불일치 {bad}/{total}) — 보간 없이 확대할 것")
    return problems


def check_one(pid):
    d = os.path.join(CHAR_DIR, pid)
    if not os.path.isdir(d):
        return [f"폴더 없음: {d}"]
    return check_dir(d, SPEC)


def contact_sheet(out_path):
    cell = 300
    cols = ["portrait.png", "talking.png", "writing.png", "idle.png", "seal.png", "header.png", "backdrop.png", "rod.png", "rodcap.png", "menubar.png", "menubar-writing.png", "reaction-pleased.png", "reaction-stern.png"]
    sheet = Image.new("RGBA", (cell * len(cols), cell * len(IDS)), (40, 40, 40, 255))
    for r, pid in enumerate(IDS):
        for c, name in enumerate(cols):
            p = os.path.join(CHAR_DIR, pid, name)
            if not os.path.exists(p):
                continue
            im = Image.open(p).convert("RGBA")
            im.thumbnail((cell - 20, cell - 20), Image.NEAREST)
            x = c * cell + (cell - im.size[0]) // 2
            y = r * cell + (cell - im.size[1]) // 2
            sheet.alpha_composite(im, (x, y))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)
    print(f"모아보기 저장: {out_path}")


def main():
    all_ok = True
    for pid in IDS:
        probs = check_one(pid)
        if probs:
            all_ok = False
            print(f"[{pid}] 문제 {len(probs)}건")
            for p in probs:
                print(f"   - {p}")
        else:
            print(f"[{pid}] OK")
    if os.path.isdir(UI_DIR):
        probs = check_dir(UI_DIR, UI_SPEC)
        if probs:
            all_ok = False
            print(f"[ui] 문제 {len(probs)}건")
            for p in probs:
                print(f"   - {p}")
        else:
            print("[ui] OK")
    if os.path.isdir(UI_DESK_DIR):
        probs = check_dir(UI_DESK_DIR, UI_DESK_SPEC)
        if probs:
            all_ok = False
            print(f"[ui/desk] 문제 {len(probs)}건")
            for p in probs:
                print(f"   - {p}")
        else:
            print("[ui/desk] OK")
    if "--contact" in sys.argv:
        contact_sheet(os.path.join(ROOT, "docs", "screenshots", "characters-contact.png"))
    print("\n결과:", "전부 OK" if all_ok else "규격 미달 항목 있음")
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
