import SwiftUI
import AppKit
import ServiceManagement

/// 첫 실행 안내: claude 확인 → 인물지 → 첫 조언
struct OnboardingView: View {
    enum Step { case check, ready, building(String), done, failed(String) }

    @State private var step: Step = .check
    @State private var claudeInfo: String = ""
    @State private var claudeFound = false
    @State private var hasHistory = false
    @State private var launchAtLogin = true
    @AppStorage(SettingsKey.model) private var model = ClaudeModel.opus.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "scroll").font(.system(size: 34)).foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text("SageBar — 현자의 아침").font(.title2.bold())
                    Text("제갈량 · 소크라테스 · 니체 · 세종대왕이 하루씩 돌아가며, 당신의 Claude Code 대화를 읽고 아침마다 조언을 올립니다.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()

            checkRow(ok: claudeFound, title: "Claude Code CLI",
                     detail: claudeInfo.isEmpty ? "확인 중…" : claudeInfo,
                     fix: claudeFound ? nil : "SageBar는 Claude Code로 글을 짓습니다. 설치한 뒤 터미널에서 claude 를 한 번 실행해 로그인하고, 아래 \"다시 확인\"을 누르세요.")
            if !claudeFound && !claudeInfo.isEmpty {
                HStack {
                    Button("설치 안내 열기") { NSWorkspace.shared.open(ClaudeCLI.installURL) }
                    Button("다시 확인") { claudeInfo = ""; detect() }
                    Spacer()
                }
            }
            checkRow(ok: hasHistory, title: "대화 기록 (~/.claude/projects)",
                     detail: hasHistory ? "찾았습니다. 이 기록으로 인물지를 짓습니다." : "아직 대화 기록이 없습니다. Claude Code를 며칠 써 본 뒤 다시 시작하면 더 정확해집니다.",
                     fix: nil)

            Picker("모델", selection: $model) {
                ForEach(ClaudeModel.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Toggle("로그인할 때 자동 시작 (권장)", isOn: $launchAtLogin)

            Spacer(minLength: 0)

            switch step {
            case .building(let msg):
                HStack { ProgressView().controlSize(.small); Text(msg) }
            case .failed(let msg):
                Text(msg).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            case .done:
                Text("준비가 끝났습니다. 매일 아침 메뉴바 아이콘에서 만나요.").font(.callout)
            default:
                EmptyView()
            }

            HStack {
                Button("나중에") { OnboardingWindowController.shared.close() }
                Spacer()
                Button(primaryLabel) { begin() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!claudeFound || isBusy)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear(perform: detect)
    }

    private var isBusy: Bool { if case .building = step { return true } else { return false } }
    private var primaryLabel: String {
        switch step {
        case .failed: return "다시 시도"
        case .done: return "닫기"
        default: return "시작 — 인물지를 짓고 첫 조언 받기"
        }
    }

    @ViewBuilder
    private func checkRow(ok: Bool, title: String, detail: String, fix: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                if let fix { Text(fix).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
            }
        }
    }

    private func detect() {
        hasHistory = ConversationExtractor.hasAnyHistory
        Task.detached {
            let found = ClaudeCLI.locate()
            let ver = found.flatMap { ClaudeCLI.version(at: $0) }
            await MainActor.run {
                claudeFound = found != nil
                claudeInfo = found.map { "\($0.path)\(ver.map { " · \($0)" } ?? "")" } ?? "찾을 수 없습니다."
            }
        }
    }

    private func begin() {
        if case .done = step { OnboardingWindowController.shared.close(); return }
        step = .building("인물지를 짓는 중 (2~5분)…")
        if launchAtLogin { try? SMAppService.mainApp.register() }
        Task {
            do {
                if !ProfileBuilder.exists { try await SageEngine.shared.rebuildProfile() }
                AppSettings.onboarded = true
                step = .done
                SageEngine.shared.start()
                OnboardingWindowController.shared.close()
                await SageEngine.shared.showToday(markShown: true)
            } catch {
                step = .failed(error.localizedDescription)
            }
        }
    }
}

@MainActor
final class OnboardingWindowController: NSWindowController {
    static let shared = OnboardingWindowController()

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "SageBar 시작하기"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.center()
        super.init(window: window)
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
