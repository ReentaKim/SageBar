import SwiftUI

/// 메뉴바 아이콘을 눌렀을 때 나오는 메뉴
struct MenuContent: View {
    @ObservedObject var engine = SageEngine.shared
    @AppStorage(SettingsKey.onboarded) private var onboarded = false

    var body: some View {
        Group {
            statusLine
            Divider()
            if onboarded {
                Button("오늘의 조언 보기") { Task { await engine.showToday() } }
                    .keyboardShortcut("o")
                Menu("지금 새로 짓기") {
                    Button("다음 순번 인물로") { engine.regenerate(persona: nil) }
                    Divider()
                    ForEach(Persona.all) { p in
                        Button("\(p.displayName)에게 듣기") { engine.regenerate(persona: p.id) }
                    }
                }
                .disabled(engine.isGenerating)
                Button("지난 조언 모두") { LetterWindowController.shared.showIndex() }
            } else {
                Button("처음 설정 시작…") { OnboardingWindowController.shared.show() }
            }
            Divider()
            SettingsLink { Text("설정…") }
                .keyboardShortcut(",")
            Button("데이터 폴더 열기") { NSWorkspace.shared.open(Paths.appSupport) }
            Divider()
            Button("SageBar 종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch engine.status {
        case .generating(let id, let stage):
            Text("\(id.persona.displayName) · \(stage)…")
        case .failed(let msg):
            Text("실패: \(msg.prefix(60))")
        case .idle:
            if let p = engine.todayPersona {
                Text("오늘의 \(p.persona.letterName) — \(p.persona.displayName)")
            } else if onboarded {
                Text("오늘의 조언이 아직 없습니다 · 다음: \(engine.nextPersona().persona.displayName)")
            } else {
                Text("현자의 아침 — 처음 설정이 필요합니다")
            }
        }
    }
}
