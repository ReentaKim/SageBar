import AppKit

/// 메뉴바 아이콘을 눌렀을 때 메뉴 맨 위에 나오는 칸.
/// 왼쪽에 32×32 도트 캐릭터(글 짓는 중이면 writing.png, 아니면 idle.png)가 움직이고, 오른쪽에 상태 글이 붙는다.
/// 캐릭터 파일이 없으면 글만 보인다.
@MainActor
final class MenuHeaderView: NSView {
    private let spriteView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var timer: Timer?

    private static let spriteSize: CGFloat = 64   // 32px 원본 → 4배 납품(128px) → 64pt 표시 (Retina 2x에 딱 맞음)

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 84))
        spriteView.imageScaling = .scaleNone
        spriteView.frame = NSRect(x: 14, y: 10, width: Self.spriteSize, height: Self.spriteSize)
        addSubview(spriteView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.frame = NSRect(x: 90, y: 44, width: 200, height: 18)
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.frame = NSRect(x: 90, y: 12, width: 200, height: 30)
        addSubview(subtitleLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 메뉴가 열릴 때마다 현재 상태로 다시 채운다
    func update(persona: PersonaID, title: String, subtitle: String, generating: Bool) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        let sheet = generating ? "writing.png" : "idle.png"
        let count = generating ? 4 : 2
        frames = Self.loadFrames(persona: persona, sheet: sheet, count: count)
        if frames.isEmpty {
            // 캐릭터가 없으면 SF Symbol 하나로
            spriteView.image = NSImage(systemSymbolName: persona.persona.menuSymbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 34, weight: .light))
            spriteView.imageScaling = .scaleProportionallyUpOrDown
            stop()
            return
        }
        spriteView.imageScaling = .scaleNone
        frameIndex = 0
        spriteView.image = frames[0]
        start(interval: generating ? 0.2 : 0.6)
    }

    func start(interval: TimeInterval) {
        stop()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // 메뉴가 열려 있는 동안(이벤트 추적 모드)에도 돌아가야 하므로 common 모드에 붙인다
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        spriteView.image = frames[frameIndex]
    }

    /// 가로 스프라이트 시트를 프레임별 NSImage로 자른다. 보간 없이 픽셀 그대로.
    static func loadFrames(persona: PersonaID, sheet: String, count: Int) -> [NSImage] {
        let url = Paths.resources.appendingPathComponent("characters/\(persona.rawValue)/\(sheet)")
        guard let src = NSImage(contentsOf: url) else { return [] }
        let pxW = src.size.width, pxH = src.size.height      // draw(from:)은 이미지 좌표(포인트) 기준
        let frameW = pxW / CGFloat(count)
        var out: [NSImage] = []
        for i in 0..<count {
            let img = NSImage(size: NSSize(width: spriteSize, height: spriteSize), flipped: false) { rect in
                NSGraphicsContext.current?.imageInterpolation = .none
                src.draw(in: rect,
                         from: NSRect(x: frameW * CGFloat(i), y: 0, width: frameW, height: pxH),
                         operation: .sourceOver, fraction: 1.0)
                return true
            }
            out.append(img)
        }
        return out
    }
}
