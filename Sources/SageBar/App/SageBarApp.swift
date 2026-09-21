import SwiftUI

@main
struct SageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    init() {
        AppSettings.registerDefaults()
        Paths.ensure()
        LetterStore.syncAssets()
        HeadlessCLI.runIfRequested()   // `SageBar --generate ...` 이면 여기서 끝난다
    }

    // 메뉴바 아이콘은 AppKit NSStatusItem(StatusBarController)으로 만든다.
    // SwiftUI MenuBarExtra는 일부 구성에서 아이콘이 나타나지 않는 문제가 있었다.
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

/// 터미널 시험용: SageBar --generate [--persona zhuge] [--model sonnet] [--profile]
/// 앱 UI를 띄우지 않고 메인 스레드에서 블로킹으로 지은 뒤 종료한다.
enum HeadlessCLI {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard args.contains("--generate") || args.contains("--profile") || args.contains("--render-preview") else { return }

        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        let model = value(after: "--model").flatMap(ClaudeModel.init(rawValue:)) ?? AppSettings.model
        let length = value(after: "--length").flatMap(LetterLength.init(rawValue:)) ?? AppSettings.length
        let persona = value(after: "--persona").flatMap(PersonaID.init(rawValue:)) ?? {
            // 순번 계산은 엔진(메인 액터)에 있으므로 여기서는 간단히 이력 기준으로 정한다
            let enabled = AppSettings.enabledPersonas
            if let last = LetterStore.lastPersona(), let i = enabled.firstIndex(of: last) { return enabled[(i + 1) % enabled.count] }
            return enabled.first ?? .zhuge
        }()
        func note(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }

        do {
            // --render-preview <persona> [--date YYYY-MM-DD]: 이미 받은 원문(raw/)을 다른 인물 테마로 다시 엮어 본다 (디자인 확인용, claude 호출 없음)
            if args.contains("--render-preview") {
                let pid = value(after: "--render-preview").flatMap(PersonaID.init(rawValue:)) ?? .zhuge
                let dateStr = value(after: "--date") ?? LetterStore.dateString()
                let raw = try String(contentsOf: LetterStore.rawURL(for: dateStr), encoding: .utf8)
                let parsed = try LetterParser.parse(raw)
                let url = try HTMLRenderer.render(letter: parsed, persona: pid.persona, date: LetterStore.dateFormatter.date(from: dateStr) ?? Date(), model: model)
                let preview = Paths.letters.appendingPathComponent("preview-\(pid.rawValue).html")
                try? FileManager.default.removeItem(at: preview)
                try FileManager.default.moveItem(at: url, to: preview)
                print(preview.path)
                exit(0)
            }
            if args.contains("--profile") || !ProfileBuilder.exists {
                note("인물지 작성 중…")
                try ProfileBuilder.build(model: model)
                print("인물지: \(Paths.profile.path)")
            }
            if args.contains("--generate") {
                var gen = LetterGenerator(model: model, length: length, recentDays: AppSettings.recentDays)
                gen.onStage = { note("  · \($0)") }
                note("글 짓는 중 (\(persona.rawValue), \(model.rawValue), \(length.rawValue))…")
                let r = try gen.generate(persona: persona, date: Date())
                note("분량 \(r.parsed.upperCount)/\(r.parsed.lowerCount)/\(r.parsed.totalCount)자, 한자 \(r.hanjaCount)자")
                print(r.url.path)
            }
            exit(0)
        } catch {
            note("실패: \(error.localizedDescription)")
            exit(1)
        }
    }
}
