import AppKit
import Combine

/// 메뉴바 아이콘과 메뉴 (AppKit NSStatusItem — 어떤 macOS 구성에서도 확실히 뜬다)
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()

    private var item: NSStatusItem!
    private let menu = NSMenu()
    private let header = MenuHeaderView()
    private var iconTimer: Timer?
    private var iconFrames: [NSImage] = []
    private var iconFrameIndex = 0
    private var cancellables: Set<AnyCancellable> = []

    private override init() {
        super.init()
    }

    func install() {
        guard item == nil else { return }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.behavior = []
        menu.delegate = self
        item.menu = menu
        updateIcon()
        SageEngine.shared.$todayPersona
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
        SageEngine.shared.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        guard let button = item?.button else { return }
        let engine = SageEngine.shared
        let symbol = engine.menuSymbol
        let personaID = engine.todayPersona ?? engine.nextPersona()

        // 글 짓는 동안: 메뉴바용 글 쓰는 실루엣(18×18 ×4)이 있으면 그것을 돌린다
        iconTimer?.invalidate(); iconTimer = nil
        if engine.isGenerating {
            let sheet = Paths.resources.appendingPathComponent("characters/\(personaID.rawValue)/menubar-writing.png")
            if let src = NSImage(contentsOf: sheet) {
                iconFrames = Self.sliceTemplate(src, count: 4, size: 18)
                if !iconFrames.isEmpty {
                    iconFrameIndex = 0
                    button.image = iconFrames[0]
                    button.appearsDisabled = false
                    button.toolTip = "SageBar — 글을 짓는 중"
                    let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                        Task { @MainActor in
                            guard let self, !self.iconFrames.isEmpty else { return }
                            self.iconFrameIndex = (self.iconFrameIndex + 1) % self.iconFrames.count
                            self.item?.button?.image = self.iconFrames[self.iconFrameIndex]
                        }
                    }
                    RunLoop.main.add(t, forMode: .common)
                    iconTimer = t
                    return
                }
            }
        }
        let custom = Paths.resources.appendingPathComponent("characters/\(personaID.rawValue)/menubar.png")
        let image: NSImage?
        if let dot = NSImage(contentsOf: custom) {
            dot.size = NSSize(width: 18, height: 18)   // 36×36 납품본을 18pt로 (Retina 2x)
            image = dot
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: "SageBar")?
                .withSymbolConfiguration(config) ?? NSImage(systemSymbolName: "scroll", accessibilityDescription: "SageBar")
        }
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = engine.isGenerating
        button.toolTip = engine.isGenerating ? "SageBar — 글을 짓는 중" : "SageBar — 현자의 아침"
    }

    /// 가로 시트를 잘라 템플릿(검정+알파) 아이콘 프레임으로
    static func sliceTemplate(_ src: NSImage, count: Int, size: CGFloat) -> [NSImage] {
        let w = src.size.width / CGFloat(count), h = src.size.height
        return (0..<count).map { i in
            let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                NSGraphicsContext.current?.imageInterpolation = .none
                src.draw(in: rect, from: NSRect(x: w * CGFloat(i), y: 0, width: w, height: h), operation: .sourceOver, fraction: 1)
                return true
            }
            img.isTemplate = true
            return img
        }
    }

    // 메뉴를 열 때마다 현재 상태로 다시 그린다
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let engine = SageEngine.shared
        let onboarded = AppSettings.onboarded

        // 맨 위: 도트 캐릭터 + 상태 (캐릭터 파일이 없으면 글만)
        let personaID = engine.todayPersona ?? engine.nextPersona()
        let (title, subtitle) = headerText(engine, onboarded: onboarded)
        header.update(persona: personaID, title: title, subtitle: subtitle, generating: engine.isGenerating)
        let headerItem = NSMenuItem()
        headerItem.view = header
        menu.addItem(headerItem)
        menu.addItem(.separator())

        if onboarded {
            menu.addItem(makeItem("오늘의 조언 보기", #selector(showToday), "o"))

            let regen = NSMenuItem(title: "지금 새로 짓기", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            sub.addItem(makeItem("다음 순번 인물로 (\(engine.nextPersona().persona.displayName))", #selector(regenerateNext), ""))
            sub.addItem(.separator())
            for p in Persona.all {
                let mi = makeItem("\(p.displayName)에게 듣기 — \(p.letterName)", #selector(regeneratePersona(_:)), "")
                mi.representedObject = p.id.rawValue
                mi.image = NSImage(systemSymbolName: p.menuSymbol, accessibilityDescription: nil)
                sub.addItem(mi)
            }
            regen.submenu = sub
            regen.isEnabled = !engine.isGenerating
            menu.addItem(regen)

            menu.addItem(makeItem("지난 조언 모두", #selector(showArchive), ""))
        } else {
            menu.addItem(makeItem("처음 설정 시작…", #selector(showOnboarding), ""))
        }

        menu.addItem(.separator())
        menu.addItem(makeItem("설정…", #selector(showSettings), ","))
        menu.addItem(makeItem("데이터 폴더 열기", #selector(openDataFolder), ""))
        menu.addItem(makeItem("GitHub에서 보기", #selector(openGitHub), ""))
        menu.addItem(.separator())
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        menu.addItem(makeItem("SageBar \(version) 종료", #selector(quit), "q"))
    }

    func menuDidClose(_ menu: NSMenu) { header.stop() }

    private func headerText(_ engine: SageEngine, onboarded: Bool) -> (String, String) {
        switch engine.status {
        case .generating(let id, let stage):
            return ("\(id.persona.displayName), 붓을 들었습니다", "\(stage)…")
        case .failed(let msg):
            return ("오늘은 붓을 놓았습니다", String(msg.prefix(80)))
        case .idle:
            if let p = engine.todayPersona {
                let entry = LetterStore.history().last { $0.date == LetterStore.dateString() }
                var sub = entry?.subtitle ?? ""
                if let fb = LetterStore.feedbackLabel(entry?.feedback) { sub += (sub.isEmpty ? "" : " · ") + "반응: \(fb)" }
                return ("오늘의 \(p.persona.letterName) — \(p.persona.displayName)", sub)
            } else if onboarded {
                return ("오늘의 조언이 아직 없습니다", "다음 차례: \(engine.nextPersona().persona.displayName)")
            } else {
                return ("현자의 아침", "처음 설정이 필요합니다")
            }
        }
    }

    private func makeItem(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = self
        return mi
    }

    // MARK: 동작

    @objc private func showToday() { Task { await SageEngine.shared.showToday() } }
    @objc private func regenerateNext() { SageEngine.shared.regenerate(persona: nil) }
    @objc private func regeneratePersona(_ sender: NSMenuItem) {
        SageEngine.shared.regenerate(persona: (sender.representedObject as? String).flatMap(PersonaID.init(rawValue:)))
    }
    @objc private func showArchive() { LetterWindowController.shared.showIndex() }
    @objc private func showOnboarding() { OnboardingWindowController.shared.show() }
    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
    @objc private func openDataFolder() { NSWorkspace.shared.open(Paths.appSupport) }
    @objc private func openGitHub() { NSWorkspace.shared.open(URL(string: "https://github.com/ReentaKim/SageBar")!) }
    @objc private func quit() { NSApp.terminate(nil) }
}
