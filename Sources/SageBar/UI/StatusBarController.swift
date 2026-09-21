import AppKit
import Combine

/// 메뉴바 아이콘과 메뉴 (AppKit NSStatusItem — 어떤 macOS 구성에서도 확실히 뜬다)
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()

    private var item: NSStatusItem!
    private let menu = NSMenu()
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
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "SageBar")?
            .withSymbolConfiguration(config) ?? NSImage(systemSymbolName: "scroll", accessibilityDescription: "SageBar")
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = engine.isGenerating
        button.toolTip = engine.isGenerating ? "SageBar — 글을 짓는 중" : "SageBar — 현자의 아침"
    }

    // 메뉴를 열 때마다 현재 상태로 다시 그린다
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let engine = SageEngine.shared
        let onboarded = AppSettings.onboarded

        let status = NSMenuItem(title: statusText(engine, onboarded: onboarded), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
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

    private func statusText(_ engine: SageEngine, onboarded: Bool) -> String {
        switch engine.status {
        case .generating(let id, let stage):
            return "\(id.persona.displayName) · \(stage)…"
        case .failed(let msg):
            return "실패: \(msg.prefix(60))"
        case .idle:
            if let p = engine.todayPersona {
                return "오늘의 \(p.persona.letterName) — \(p.persona.displayName)"
            } else if onboarded {
                return "오늘의 조언이 아직 없습니다 · 다음: \(engine.nextPersona().persona.displayName)"
            } else {
                return "현자의 아침 — 처음 설정이 필요합니다"
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
