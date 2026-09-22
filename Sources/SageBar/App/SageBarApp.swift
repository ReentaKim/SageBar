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
        guard args.contains("--generate") || args.contains("--profile") || args.contains("--render-preview") || args.contains("--rerender") || args.contains("--debug-menu-header") || args.contains("--debug-waiting") else { return }

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
                // 오늘자 파일을 건드리지 않도록 별도 이름으로 바로 쓴다
                let preview = Paths.letters.appendingPathComponent("preview-\(pid.rawValue).html")
                _ = try HTMLRenderer.render(letter: parsed, persona: pid.persona,
                                            date: LetterStore.dateFormatter.date(from: dateStr) ?? Date(),
                                            model: model, outputURL: preview)
                print(preview.path)
                exit(0)
            }
            // --debug-waiting <persona> [--fail]: 대기(또는 실패) 화면을 letters/_waiting.html 로 써서 확인
            if args.contains("--debug-waiting") {
                let pid = value(after: "--debug-waiting").flatMap(PersonaID.init(rawValue:)) ?? .zhuge
                let p = pid.persona
                let url = args.contains("--fail")
                    ? HTMLRenderer.writeStatusPage(persona: p, title: p.failTitle, line: p.failLine, hint: "메뉴바 아이콘 → \"지금 새로 짓기\"로 다시 시도할 수 있습니다.", animated: false, extra: "<div class=\"err\">시험용 오류 문구</div>")
                    : HTMLRenderer.writeStatusPage(persona: p, title: p.waitingTitle, line: p.waitingLine, hint: "보통 3~5분, 길면 30분 남짓 걸립니다. 이 창은 완성되면 저절로 바뀝니다.", animated: true)
                print(url?.path ?? "실패"); exit(url == nil ? 1 : 0)
            }
            // --debug-menu-header <persona> <out.png> [--generating]: 메뉴 상단 캐릭터 칸을 그림으로 떠서 확인
            if args.contains("--debug-menu-header") {
                let pid = value(after: "--debug-menu-header").flatMap(PersonaID.init(rawValue:)) ?? .zhuge
                let out = args.first(where: { $0.hasSuffix(".png") }) ?? "menu-header.png"
                let generating = args.contains("--generating")
                let data: Data? = MainActor.assumeIsolated {   // App.init은 메인 스레드에서 돈다
                    let view = MenuHeaderView()
                    view.update(persona: pid, title: "오늘의 \(pid.persona.letterName) — \(pid.persona.displayName)",
                                subtitle: generating ? "글을 짓는 중…" : "말은 짧아도 뜻은 길게", generating: generating)
                    view.stop()
                    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
                    view.cacheDisplay(in: view.bounds, to: rep)
                    return rep.representation(using: .png, properties: [:])
                }
                guard let data else { exit(1) }
                try data.write(to: URL(fileURLWithPath: out))
                print(out); exit(0)
            }
            // --rerender [YYYY-MM-DD]: 보관된 원문(raw/)을 현재 템플릿·자산으로 다시 엮는다 (claude 호출 없음).
            // 템플릿이나 캐릭터 그림이 바뀐 뒤 이미 지어진 편지에 새 모습을 입힐 때 쓴다.
            if args.contains("--rerender") {
                let dateStr = value(after: "--rerender").flatMap { $0.hasPrefix("20") ? $0 : nil } ?? LetterStore.dateString()
                guard let pid = LetterStore.personaForDate(dateStr) else {
                    note("\(dateStr)의 인물 기록이 없어 다시 엮을 수 없습니다."); exit(1)
                }
                let raw = try String(contentsOf: LetterStore.rawURL(for: dateStr), encoding: .utf8)
                let parsed = try LetterParser.parse(raw)
                let url = try HTMLRenderer.render(letter: parsed, persona: pid.persona,
                                                  date: LetterStore.dateFormatter.date(from: dateStr) ?? Date(), model: model)
                LetterStore.renderIndex()
                print(url.path)
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
                // --date YYYY-MM-DD 로 다른 날짜의 글을 지을 수 있다 (점검·연속성 시험용)
                let genDate = value(after: "--date").flatMap { LetterStore.dateFormatter.date(from: $0) } ?? Date()
                let r = try gen.generate(persona: persona, date: genDate)
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
