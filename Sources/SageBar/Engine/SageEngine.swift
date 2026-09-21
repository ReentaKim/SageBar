import Foundation
import AppKit
import Combine

/// 앱 쪽 총괄: 상태 게시, 인물 순번, 스케줄, 창 갱신. 실제 짓기는 LetterGenerator가 한다.
@MainActor
final class SageEngine: ObservableObject {
    static let shared = SageEngine()

    enum Status: Equatable {
        case idle
        case generating(PersonaID, String)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var todayLetter: URL?
    @Published private(set) var todayPersona: PersonaID?

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var generationTask: Task<URL, Error>?

    var isGenerating: Bool { if case .generating = status { return true } else { return false } }
    var menuSymbol: String { (todayPersona ?? nextPersona()).persona.menuSymbol }

    private init() { refreshTodayState() }

    func refreshTodayState() {
        let today = LetterStore.dateString()
        if LetterStore.hasLetter(for: today) {
            todayLetter = LetterStore.letterURL(for: today)
            todayPersona = LetterStore.personaForDate(today)
        } else {
            todayLetter = nil
            todayPersona = nil
        }
    }

    // MARK: 인물 선택

    func nextPersona() -> PersonaID {
        let enabled = AppSettings.enabledPersonas
        switch AppSettings.personaMode {
        case .fixed:
            return enabled.contains(AppSettings.fixedPersona) ? AppSettings.fixedPersona : (enabled.first ?? .zhuge)
        case .random:
            return enabled.randomElement() ?? .zhuge
        case .rotate:
            guard let last = LetterStore.lastPersona(), let idx = enabled.firstIndex(of: last) else {
                return enabled.first ?? .zhuge
            }
            return enabled[(idx + 1) % enabled.count]
        }
    }

    // MARK: 스케줄

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    self?.tick()
                }
            }
        }
        tick()
    }

    /// 1분마다: 표시 시각이 지났고 오늘 아직 안 보여줬으면 짓고 보여준다.
    /// 표시 시각 N분 전부터는 조용히 미리 짓는다.
    func tick() {
        guard AppSettings.onboarded, !isGenerating else { return }
        let now = Date()
        let today = LetterStore.dateString(now)
        let minutesNow = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let showAt = AppSettings.showMinutes
        let prebuildAt = showAt - AppSettings.prebuildMinutes

        if minutesNow >= showAt, AppSettings.lastShownDate != today {
            Task { await self.showToday(markShown: true) }
        } else if minutesNow >= prebuildAt, minutesNow < showAt, !LetterStore.hasLetter(for: today) {
            LetterStore.log("미리 짓기 시작")
            Task { _ = try? await self.ensureTodayLetter(force: false, persona: nil) }
        }
    }

    // MARK: 동작

    func showToday(markShown: Bool = false) async {
        let today = LetterStore.dateString()
        LetterStore.log("오늘 글 표시 요청 (markShown=\(markShown))")
        LetterWindowController.shared.show()
        if markShown { AppSettings.lastShownDate = today }
        if let url = try? await ensureTodayLetter(force: false, persona: nil) {
            LetterWindowController.shared.load(url)
        }
    }

    func regenerate(persona: PersonaID?) {
        Task {
            LetterWindowController.shared.show()
            if let url = try? await ensureTodayLetter(force: true, persona: persona) {
                LetterWindowController.shared.load(url)
            }
        }
    }

    /// 오늘 글이 있으면 경로를, 없으면 지어서 돌려준다. 동시 호출은 진행 중인 작업을 함께 기다린다.
    func ensureTodayLetter(force: Bool, persona: PersonaID?) async throws -> URL {
        let today = LetterStore.dateString()
        if !force, LetterStore.hasLetter(for: today) {
            refreshTodayState()
            return LetterStore.letterURL(for: today)
        }
        if let running = generationTask { return try await running.value }

        let chosen = persona ?? nextPersona()
        let task = Task<URL, Error> { try await self.generate(persona: chosen) }
        generationTask = task
        defer { generationTask = nil }
        return try await task.value
    }

    private func generate(persona id: PersonaID) async throws -> URL {
        let persona = id.persona
        status = .generating(id, "붓을 드는 중")
        LetterWindowController.shared.showWaiting(persona: persona,
            hint: "보통 3~5분, 길면 30분 남짓 걸립니다. 이 창은 완성되면 저절로 바뀝니다.")

        var generator = LetterGenerator(model: AppSettings.model, length: AppSettings.length, recentDays: AppSettings.recentDays)
        generator.onStage = { stage in
            Task { @MainActor in
                SageEngine.shared.status = .generating(id, stage)
                if stage.contains("인물지") {
                    LetterWindowController.shared.showWaiting(persona: persona,
                        hint: "처음 한 번, 지금까지의 대화를 읽어 인물지를 짓습니다. 2~5분 걸립니다.")
                }
            }
        }
        do {
            let result = try await Task.detached(priority: .userInitiated) { try generator.generate(persona: id, date: Date()) }.value
            refreshTodayState()
            status = .idle
            return result.url
        } catch {
            let msg = error.localizedDescription
            status = .failed(msg)
            LetterWindowController.shared.showFailure(persona: persona, message: msg)
            throw error
        }
    }

    func rebuildProfile() async throws {
        let model = AppSettings.model
        try await Task.detached(priority: .userInitiated) { try ProfileBuilder.build(model: model) }.value
    }
}
