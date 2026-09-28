import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("일반", systemImage: "gear") }
            PersonaSettings().tabItem { Label("인물", systemImage: "person.3") }
            ScopeSettings().tabItem { Label("읽는 범위", systemImage: "eye") }
            AdvancedSettings().tabItem { Label("고급", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 480, height: 460)
    }
}

// MARK: 일반

struct GeneralSettings: View {
    @AppStorage(SettingsKey.showMinutes) private var showMinutes = 7 * 60
    @AppStorage(SettingsKey.prebuildMinutes) private var prebuildMinutes = 20
    @AppStorage(SettingsKey.length) private var length = LetterLength.normal.rawValue
    @AppStorage(SettingsKey.model) private var model = ClaudeModel.opus.rawValue
    @AppStorage(SettingsKey.checkUpdates) private var checkUpdates = true
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)
    @State private var loginError: String?

    private var showTime: Binding<Date> {
        Binding(
            get: {
                let start = Calendar.current.startOfDay(for: Date())
                return start.addingTimeInterval(Double(showMinutes) * 60)
            },
            set: { d in
                showMinutes = Calendar.current.component(.hour, from: d) * 60 + Calendar.current.component(.minute, from: d)
            })
    }

    var body: some View {
        Form {
            Section("아침 조언") {
                DatePicker("보여주는 시각", selection: showTime, displayedComponents: .hourAndMinute)
                Stepper("\(prebuildMinutes)분 전에 미리 짓기", value: $prebuildMinutes, in: 0...120, step: 5)
                Text("그 시각에 Mac이 꺼져 있었으면, 다음에 켜서 로그인한 직후 보여줍니다. 하루에 한 번만 자동으로 뜹니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("글") {
                Picker("길이", selection: $length) {
                    ForEach(LetterLength.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker("모델", selection: $model) {
                    ForEach(ClaudeModel.allCases) { Text($0.label).tag($0.rawValue) }
                }
            }
            Section("시작") {
                Toggle("새 버전이 나오면 메뉴에 알리기", isOn: $checkUpdates)
                    .onChange(of: checkUpdates) { _, on in
                        if on { UpdateChecker.shared.check() } else { StatusBarController.shared.refreshIcon() }
                    }
                Toggle("로그인할 때 SageBar 자동 시작", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = (SMAppService.mainApp.status == .enabled)
                        }
                    }
                if let e = loginError { Text(e).font(.caption).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: 인물

struct PersonaSettings: View {
    @AppStorage(SettingsKey.personaMode) private var mode = PersonaMode.rotate.rawValue
    @AppStorage(SettingsKey.fixedPersona) private var fixed = PersonaID.zhuge.rawValue
    @AppStorage(SettingsKey.enabledPersonas) private var enabledRaw = PersonaID.allCases.map(\.rawValue).joined(separator: ",")

    private func isEnabled(_ id: PersonaID) -> Bool { enabledRaw.split(separator: ",").contains(Substring(id.rawValue)) }
    private func setEnabled(_ id: PersonaID, _ on: Bool) {
        var set = Set(enabledRaw.split(separator: ",").map(String.init))
        if on { set.insert(id.rawValue) } else if set.count > 1 { set.remove(id.rawValue) }
        enabledRaw = PersonaID.allCases.map(\.rawValue).filter { set.contains($0) }.joined(separator: ",")
    }

    var body: some View {
        Form {
            Section("누가 조언할까") {
                Picker("고르는 방식", selection: $mode) {
                    ForEach(PersonaMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                if mode == PersonaMode.fixed.rawValue {
                    Picker("고정 인물", selection: $fixed) {
                        ForEach(Persona.all) { Text($0.displayName).tag($0.id.rawValue) }
                    }
                }
            }
            if mode != PersonaMode.fixed.rawValue {
                Section("포함할 인물") {
                    ForEach(Persona.all) { p in
                        Toggle(isOn: Binding(get: { isEnabled(p.id) }, set: { setEnabled(p.id, $0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.displayName).font(.body)
                                Text("\(p.letterName) · \(p.upperTitle) / \(p.lowerTitle)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: 읽는 범위

struct ScopeSettings: View {
    @AppStorage(SettingsKey.excludedProjects) private var excludedRaw = ""
    @AppStorage(SettingsKey.includePlans) private var includePlans = true
    @AppStorage(SettingsKey.recentDays) private var recentDays = 14
    @State private var projects: [ConversationExtractor.ProjectSummary]?
    @State private var changed = false
    @State private var profileBusy = false
    @State private var profileMessage: String?

    private var excluded: Set<String> { Set(excludedRaw.split(separator: "\n").map(String.init)) }
    private func setIncluded(_ folder: String, _ on: Bool) {
        var set = excluded
        if on { set.remove(folder) } else { set.insert(folder) }
        excludedRaw = set.sorted().joined(separator: "\n")
        changed = true
    }

    var body: some View {
        Form {
            Section {
                if let projects {
                    if projects.isEmpty {
                        Text("아직 Claude Code 대화 기록이 없습니다.").foregroundStyle(.secondary)
                    }
                    ForEach(projects) { p in
                        Toggle(isOn: Binding(get: { !excluded.contains(p.folder) }, set: { setIncluded(p.folder, $0) })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.body).lineLimit(1).truncationMode(.middle)
                                Text(p.lastDate.isEmpty ? "발화 없음" : "최근 \(recentDays)일 \(p.recentCount)건 · 마지막 \(p.lastDate)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    HStack { ProgressView().controlSize(.small); Text("대화 기록을 살피는 중…").foregroundStyle(.secondary) }
                }
            } header: {
                Text("현자가 읽을 프로젝트")
            } footer: {
                Text("끈 프로젝트의 대화는 편지·인물지·답장 어디에도 쓰지 않습니다. 회사 일처럼 조언에 섞이면 안 되는 폴더를 끄세요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("계획 문서(~/.claude/plans)도 읽기", isOn: $includePlans)
                    .onChange(of: includePlans) { _, _ in changed = true }
            }
            if changed {
                Section {
                    HStack {
                        Text("이미 지은 인물지에는 뺀 내용이 남아 있을 수 있습니다.").font(.caption)
                        Spacer()
                        Button(profileBusy ? "짓는 중…" : "인물지 새로 짓기") {
                            profileBusy = true; profileMessage = nil
                            Task {
                                do { try await SageEngine.shared.rebuildProfile(fresh: true); profileMessage = "새로 지었습니다."; changed = false }
                                catch { profileMessage = error.localizedDescription }
                                profileBusy = false
                            }
                        }
                        .disabled(profileBusy)
                    }
                    if let m = profileMessage { Text(m).font(.caption) }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            let days = recentDays
            projects = await Task.detached { ConversationExtractor.projectSummaries(days: days) }.value
        }
    }
}

// MARK: 고급

struct AdvancedSettings: View {
    @AppStorage(SettingsKey.claudePath) private var claudePath = ""
    @AppStorage(SettingsKey.recentDays) private var recentDays = 14
    @AppStorage(SettingsKey.profileUpdatedAt) private var profileUpdatedAt = ""
    @State private var detected: String = "확인 중…"
    @State private var profileBusy = false
    @State private var profileMessage: String?

    var body: some View {
        Form {
            Section("Claude Code CLI") {
                TextField("claude 경로 (비우면 자동 탐색)", text: $claudePath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(detect)
                HStack {
                    Text(detected).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("다시 확인", action: detect)
                }
            }
            Section("재료") {
                Stepper("최근 \(recentDays)일 대화를 재료로", value: $recentDays, in: 3...60)
                HStack {
                    VStack(alignment: .leading) {
                        Text("인물지 (나에 대한 요약)")
                        Text(profileUpdatedAt.isEmpty ? "아직 없음" : "마지막 갱신: \(profileUpdatedAt) · 매주 자동 갱신")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(profileBusy ? "갱신 중…" : "지금 갱신") {
                        profileBusy = true; profileMessage = nil
                        Task {
                            do { try await SageEngine.shared.rebuildProfile(); profileMessage = "갱신했습니다." }
                            catch { profileMessage = error.localizedDescription }
                            profileBusy = false
                        }
                    }
                    .disabled(profileBusy)
                }
                if let m = profileMessage { Text(m).font(.caption) }
                HStack {
                    Button("인물지 열기") { NSWorkspace.shared.open(Paths.profile) }
                        .disabled(!ProfileBuilder.exists)
                    Button("로그 열기") { NSWorkspace.shared.open(Paths.logFile) }
                    Button("데이터 폴더") { NSWorkspace.shared.open(Paths.appSupport) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: detect)
    }

    private func detect() {
        detected = "확인 중…"
        Task.detached {
            let found = ClaudeCLI.locate()
            let ver = found.flatMap { ClaudeCLI.version(at: $0) }
            let text = found.map { "\($0.path)\(ver.map { " · \($0)" } ?? "")" } ?? "찾을 수 없음 — Claude Code를 설치하세요 (https://claude.com/claude-code)"
            await MainActor.run { detected = text }
        }
    }
}
