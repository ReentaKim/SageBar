#!/bin/bash
# generate-icons.sh — 앱 아이콘(AppIcon.icns)을 Swift 스크립트로 그려서 만든다. 외부 도구 불필요.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/Resources"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/draw.swift" <<'SWIFT'
import AppKit
// 두루마리 위에 붓 자국 하나 — 한지 색 배경, 주홍 인장 점
func draw(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let s = size
    let r = NSRect(x: 0, y: 0, width: s, height: s)
    // 배경: 둥근 사각 (macOS 아이콘 비율), 한지
    let bg = NSBezierPath(roundedRect: r.insetBy(dx: s*0.06, dy: s*0.06), xRadius: s*0.22, yRadius: s*0.22)
    NSColor(calibratedRed: 0.95, green: 0.91, blue: 0.83, alpha: 1).setFill(); bg.fill()
    // 상하 두루마리 축
    let rod = NSColor(calibratedRed: 0.29, green: 0.21, blue: 0.14, alpha: 1)
    for y in [s*0.13, s*0.79] {
        let p = NSBezierPath(roundedRect: NSRect(x: s*0.14, y: y, width: s*0.72, height: s*0.08), xRadius: s*0.04, yRadius: s*0.04)
        rod.setFill(); p.fill()
    }
    // 글줄 (세로쓰기 느낌의 짧은 선들)
    NSColor(calibratedRed: 0.11, green: 0.10, blue: 0.09, alpha: 0.85).setStroke()
    for (i, x) in [s*0.66, s*0.52, s*0.38].enumerated() {
        let line = NSBezierPath(); line.lineWidth = s*0.035; line.lineCapStyle = .round
        let top = s*0.70, bottom = s*0.30 + CGFloat(i) * s*0.06
        line.move(to: NSPoint(x: x, y: top)); line.line(to: NSPoint(x: x, y: bottom)); line.stroke()
    }
    // 주홍 인장
    let seal = NSBezierPath(roundedRect: NSRect(x: s*0.24, y: s*0.27, width: s*0.10, height: s*0.10), xRadius: s*0.015, yRadius: s*0.015)
    NSColor(calibratedRed: 0.61, green: 0.13, blue: 0.15, alpha: 1).setFill(); seal.fill()
    img.unlockFocus()
    return img
}
let outDir = CommandLine.arguments[1]
for (name, px) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),
                   ("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),
                   ("icon_512x512",512),("icon_512x512@2x",1024)] {
    let img = draw(size: CGFloat(px))
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
// 스크린샷·README용 큰 PNG
let big = draw(size: 1024)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
big.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024)); NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/../AppIcon-1024.png"))
SWIFT

mkdir -p "$TMP/AppIcon.iconset"
swiftc -O -o "$TMP/draw" "$TMP/draw.swift" 2>/dev/null
"$TMP/draw" "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$OUT/AppIcon.icns"
cp "$TMP/AppIcon-1024.png" "$ROOT/docs/icon.png"
echo "✔ $OUT/AppIcon.icns, docs/icon.png"
