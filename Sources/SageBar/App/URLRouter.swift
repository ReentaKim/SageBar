import AppKit

/// sagebar:// URL 처리 (Finder·터미널·브라우저에서 온 것과 편지 창 안 링크를 한곳에서)
///   sagebar://today · sagebar://regenerate[?persona=zhuge] · sagebar://archive · sagebar://settings
///   sagebar://feedback?date=YYYY-MM-DD&value=sharp|dull
@MainActor
enum URLRouter {
    static func handle(_ url: URL) {
        LetterStore.log("URL 요청: \(url.absoluteString)")
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        func query(_ name: String) -> String? { comps?.queryItems?.first { $0.name == name }?.value }

        switch url.host ?? "" {
        case "today":
            Task { await SageEngine.shared.showToday() }
        case "regenerate":
            SageEngine.shared.regenerate(persona: query("persona").flatMap(PersonaID.init(rawValue:)))
        case "archive":
            LetterWindowController.shared.showIndex()
        case "print":
            LetterWindowController.shared.printCurrent()
        case "profile":
            if ProfileBuilder.exists { NSWorkspace.shared.open(Paths.profile) } else { NSWorkspace.shared.open(Paths.appSupport) }
        case "settings":
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        case "feedback":
            guard let date = query("date"), let value = query("value"), ["sharp", "dull", "miss"].contains(value) else {
                LetterStore.log("피드백 URL 형식 오류"); return
            }
            let ok = LetterStore.setFeedback(date: date, value: value)
            LetterStore.log("피드백 기록: \(date) → \(LetterStore.feedbackLabel(value) ?? value) (\(ok ? "저장" : "해당 날짜 없음"))")
        default:
            Task { await SageEngine.shared.showToday() }
        }
    }
}
