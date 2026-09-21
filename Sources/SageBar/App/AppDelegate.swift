import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        LetterStore.log("SageBar 시작 (v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"))")
        StatusBarController.shared.install()
        if AppSettings.onboarded {
            SageEngine.shared.start()
        } else {
            OnboardingWindowController.shared.show()
        }
    }

    /// sagebar://today · sagebar://regenerate[?persona=zhuge] · sagebar://archive · sagebar://settings
    /// (단축어·Raycast·터미널 `open "sagebar://today"` 에서 쓸 수 있다)
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            LetterStore.log("URL 요청: \(url.absoluteString)")
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            switch url.host ?? "" {
            case "today":
                Task { await SageEngine.shared.showToday() }
            case "regenerate":
                let pid = comps?.queryItems?.first(where: { $0.name == "persona" })?.value.flatMap(PersonaID.init(rawValue:))
                SageEngine.shared.regenerate(persona: pid)
            case "archive":
                LetterWindowController.shared.showIndex()
            case "settings":
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            default:
                Task { await SageEngine.shared.showToday() }
            }
        }
    }

    // 메뉴바 앱이라 창을 모두 닫아도 계속 산다
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // Dock/Finder에서 다시 열면 오늘 글을 보여준다
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if AppSettings.onboarded { Task { await SageEngine.shared.showToday() } }
        else { OnboardingWindowController.shared.show() }
        return true
    }
}
