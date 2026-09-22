import Foundation

/// 앱 데이터 폴더(~/Library/Application Support/SageBar)와 번들 리소스 경로.
enum Paths {
    static let appSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SageBar", isDirectory: true)
    }()
    static var letters: URL { appSupport.appendingPathComponent("letters", isDirectory: true) }
    static var raw: URL { appSupport.appendingPathComponent("raw", isDirectory: true) }
    static var logs: URL { appSupport.appendingPathComponent("logs", isDirectory: true) }
    static var assets: URL { appSupport.appendingPathComponent("assets", isDirectory: true) }
    static var profileHistory: URL { appSupport.appendingPathComponent("profile-history", isDirectory: true) }
    static var profile: URL { appSupport.appendingPathComponent("profile.md") }
    static var recent: URL { appSupport.appendingPathComponent("recent.md") }
    static var history: URL { appSupport.appendingPathComponent("history.jsonl") }
    static var logFile: URL { logs.appendingPathComponent("sagebar.log") }
    static var waitingPage: URL { letters.appendingPathComponent("_waiting.html") }
    static var indexPage: URL { letters.appendingPathComponent("index.html") }

    static func ensure() {
        for dir in [appSupport, letters, raw, logs, assets, profileHistory] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// 템플릿·스타일이 든 리소스 폴더. 앱 번들 → 환경변수 → 소스 트리 순으로 찾는다.
    static let resources: URL = {
        let fm = FileManager.default
        if let r = Bundle.main.resourceURL,
           fm.fileExists(atPath: r.appendingPathComponent("templates/letter.html").path) {
            return r
        }
        if let env = ProcessInfo.processInfo.environment["SAGEBAR_RESOURCES"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // swift run 개발 모드: Sources/SageBar/Model/LetterStore.swift → 저장소 루트/Resources
        let here = URL(fileURLWithPath: #filePath)
        return here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
    }()
}

struct HistoryEntry: Codable {
    let date: String
    let persona: String
    let subtitle: String
    var actions: [String]? = nil     // 그날 권한 실천 항목 (다음 날 점검 근거)
    var feedback: String? = nil      // "sharp"(찔렸다) / "dull"(뻔했다) / "miss"(내 얘기와 달랐다)
    var mood: String? = nil          // 지난 조언 점검 판정 pleased / stern / neutral
}

enum LetterStore {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dateString(_ date: Date = Date()) -> String { dateFormatter.string(from: date) }
    static func letterURL(for date: String) -> URL { Paths.letters.appendingPathComponent("\(date).html") }
    static func rawURL(for date: String) -> URL { Paths.raw.appendingPathComponent("\(date).txt") }
    static func hasLetter(for date: String) -> Bool { FileManager.default.fileExists(atPath: letterURL(for: date).path) }

    // MARK: 로그
    static func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: Paths.logFile.path),
               let h = try? FileHandle(forWritingTo: Paths.logFile) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: Paths.logFile)
            }
        }
        #if DEBUG
        print(line, terminator: "")
        #endif
    }

    // MARK: 이력
    static func history() -> [HistoryEntry] {
        guard let text = try? String(contentsOf: Paths.history, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        return text.split(separator: "\n").compactMap { line -> HistoryEntry? in
            guard let d = line.data(using: .utf8) else { return nil }
            return try? dec.decode(HistoryEntry.self, from: d)
        }.sorted { $0.date < $1.date }   // 지은 순서가 아니라 날짜순 (다른 날짜를 나중에 지어도 순번·점검이 어긋나지 않게)
    }

    /// 같은 날짜 항목은 교체하고 맨 뒤에 덧붙인다 (다시 짓기 시 중복 방지).
    static func appendHistory(_ entry: HistoryEntry) {
        var entry = entry
        let all = history()
        // 같은 날짜를 다시 지을 때 이미 남긴 반응은 보존한다
        if entry.feedback == nil, let old = all.first(where: { $0.date == entry.date }) { entry.feedback = old.feedback }
        var rows = all.filter { $0.date != entry.date }
        rows.append(entry)
        let enc = JSONEncoder()
        let lines = rows.compactMap { try? enc.encode($0) }.compactMap { String(data: $0, encoding: .utf8) }
        try? (lines.joined(separator: "\n") + "\n").write(to: Paths.history, atomically: true, encoding: .utf8)
    }

    static func recentTopics(limit: Int = 14) -> String {
        let rows = history().suffix(limit)
        return rows.map { "- \($0.date) (\(PersonaID(rawValue: $0.persona)?.persona.displayName ?? $0.persona)): \($0.subtitle)" }
            .joined(separator: "\n")
    }

    /// 주어진 날짜보다 앞선 가장 최근 항목 (지난 조언 점검 대상)
    static func previousEntry(before date: String) -> HistoryEntry? {
        history().filter { $0.date < date }.last
    }

    /// 편지 아래 버튼으로 남긴 반응을 기록한다. 해당 날짜 항목이 없으면 false.
    @discardableResult
    static func setFeedback(date: String, value: String) -> Bool {
        var rows = history()
        guard let i = rows.firstIndex(where: { $0.date == date }) else { return false }
        rows[i].feedback = value
        let enc = JSONEncoder()
        let lines = rows.compactMap { try? enc.encode($0) }.compactMap { String(data: $0, encoding: .utf8) }
        try? (lines.joined(separator: "\n") + "\n").write(to: Paths.history, atomically: true, encoding: .utf8)
        return true
    }

    static func feedbackLabel(_ value: String?) -> String? {
        switch value { case "sharp": return "찔렸다"; case "dull": return "뻔했다"; case "miss": return "내 얘기와 달랐다"; default: return nil }
    }

    /// 프롬프트용 "독자의 반응" 요약 — 최근 10편의 반응과 인물별 집계
    static func feedbackSummary(limit: Int = 10) -> String {
        let rated = history().filter { $0.feedback != nil }
        guard !rated.isEmpty else { return "" }
        var byPersona: [String: (sharp: Int, dull: Int, miss: Int)] = [:]
        for r in rated {
            var c = byPersona[r.persona] ?? (0, 0, 0)
            switch r.feedback { case "sharp": c.sharp += 1; case "dull": c.dull += 1; default: c.miss += 1 }
            byPersona[r.persona] = c
        }
        var out = "인물별 집계: " + byPersona.map { k, v in
            "\(PersonaID(rawValue: k)?.persona.displayName ?? k) 찔렸다 \(v.sharp) · 뻔했다 \(v.dull) · 달랐다 \(v.miss)"
        }.joined(separator: " / ")
        out += "\n최근 반응:\n" + rated.suffix(limit).map {
            "- \($0.date) \(PersonaID(rawValue: $0.persona)?.persona.displayName ?? $0.persona) 「\($0.subtitle)」 → \(feedbackLabel($0.feedback) ?? "")"
        }.joined(separator: "\n")
        return out
    }

    /// 최근 N편 가운데 "내 얘기와 달랐다" 반응 수 — 2 이상이면 인물지를 다시 짓는다
    static func recentMissCount(last n: Int = 7) -> Int {
        history().suffix(n).filter { $0.feedback == "miss" }.count
    }

    static func lastPersona() -> PersonaID? {
        guard let last = history().last else { return nil }
        return PersonaID(rawValue: last.persona)
    }

    static func personaForDate(_ date: String) -> PersonaID? {
        history().first { $0.date == date }.flatMap { PersonaID(rawValue: $0.persona) }
    }

    // MARK: 자산 동기화 — 스타일·폰트·인장을 데이터 폴더로 복사 (편지가 앱 위치와 무관하게 열리도록)
    static func syncAssets() {
        let fm = FileManager.default
        for sub in ["styles", "fonts", "seals", "characters", "ui"] {
            let src = Paths.resources.appendingPathComponent(sub)
            let dst = Paths.assets.appendingPathComponent(sub)
            guard fm.fileExists(atPath: src.path) else { continue }
            try? fm.removeItem(at: dst)
            try? fm.copyItem(at: src, to: dst)
        }
    }

    // MARK: 목록
    struct LetterInfo { let date: String; let persona: PersonaID?; let subtitle: String }

    static func listLetters() -> [LetterInfo] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: Paths.letters.path)) ?? []
        let hist = Dictionary(uniqueKeysWithValues: history().map { ($0.date, $0) })
        return files
            .filter { $0.hasSuffix(".html") && $0.hasPrefix("20") }
            .map { String($0.dropLast(5)) }
            .sorted(by: >)
            .map { d in
                let h = hist[d]
                return LetterInfo(date: d, persona: h.flatMap { PersonaID(rawValue: $0.persona) }, subtitle: h?.subtitle ?? "")
            }
    }

    /// 지난 조언 모음 = 「현자의 서재」 장면 (templates/archive.html). 자산 없으면 CSS 폴백 장면.
    static func renderIndex() {
        let seat = personaForDate(dateString()) ?? nextPersonaGuess()
        renderArchive(seat: seat, generating: false)
    }

    /// 엔진 없이 순번을 어림잡을 때 (헤드리스·렌더 전용)
    static func nextPersonaGuess() -> PersonaID {
        let enabled = AppSettings.enabledPersonas
        guard let last = lastPersona(), let i = enabled.firstIndex(of: last) else { return enabled.first ?? .zhuge }
        return enabled[(i + 1) % enabled.count]
    }

    static func renderArchive(seat: PersonaID, generating: Bool) {
        let tplURL = Paths.resources.appendingPathComponent("templates/archive.html")
        guard let tpl = try? String(contentsOf: tplURL, encoding: .utf8) else { return }
        let today = dateString()
        let hist = Dictionary(uniqueKeysWithValues: history().map { ($0.date, $0) })
        let items = listLetters().sorted { $0.date < $1.date }

        // 장면 데이터
        let data: [[String: Any]] = items.map { info in
            let h = hist[info.date]
            return ["date": info.date, "persona": info.persona?.rawValue ?? "zhuge", "subtitle": info.subtitle,
                    "feedback": h?.feedback ?? "", "mood": h?.mood ?? ""]
        }
        // 집계
        var perPersona: [String: [String: Int]] = [:]
        var fb = ["sharp": 0, "dull": 0, "miss": 0]
        var moodTotal = 0, moodPleased = 0
        for info in items {
            let pid = info.persona?.rawValue ?? "zhuge"
            var c = perPersona[pid] ?? ["count": 0, "sharp": 0]
            c["count", default: 0] += 1
            let h = hist[info.date]
            if h?.feedback == "sharp" { c["sharp", default: 0] += 1 }
            if let f = h?.feedback, fb[f] != nil { fb[f, default: 0] += 1 }
            if let m = h?.mood, ["pleased", "stern"].contains(m) { moodTotal += 1; if m == "pleased" { moodPleased += 1 } }
            perPersona[pid] = c
        }
        // 연속 일수: 오늘(또는 어제)부터 거꾸로 이어진 날 수
        let dates = Set(items.map(\.date))
        var streak = 0
        var cursor = dateFormatter.date(from: today) ?? Date()
        if !dates.contains(today) { cursor = cursor.addingTimeInterval(-86400) }
        while dates.contains(dateString(cursor)) { streak += 1; cursor = cursor.addingTimeInterval(-86400) }

        let stats: [String: Any] = ["total": items.count, "streak": streak, "moodTotal": moodTotal, "moodPleased": moodPleased,
                                    "fb": fb, "perPersona": perPersona]
        let personas: [[String: String]] = Persona.all.map { ["id": $0.id.rawValue, "name": $0.displayName, "letter": $0.letterName] }
        func json(_ v: Any) -> String {
            guard let d = try? JSONSerialization.data(withJSONObject: v, options: []), let s = String(data: d, encoding: .utf8) else { return "null" }
            return s.replacingOccurrences(of: "</", with: "<\\/")
        }
        let hasArt = HTMLRenderer.hasUIFile("desk/desk-bg.png")
        let sp = seat.persona
        // 앉은 현자: 서재 전용 스프라이트(ui/desk/sage-<id>.png, 6프레임)가 있으면 그것을, 없으면 편지용 writing.png(4프레임)
        let hasSeatSprite = HTMLRenderer.hasUIFile("desk/sage-\(seat.rawValue).png")
        let seatSheet = hasSeatSprite ? "../assets/ui/desk/sage-\(seat.rawValue).png" : "../assets/characters/\(seat.rawValue)/writing.png"
        let seatFrames = hasSeatSprite ? "6" : "4"
        let bodyClass = (hasArt ? "has-art" : "") + (HTMLRenderer.hasUIFile("desk/menu-list.png") ? " has-list-icon" : "")
        let hint = generating ? "\(sp.displayName)이(가) 글을 짓는 중" : (dates.contains(today) ? "오늘의 \(sp.letterName) 보기" : "\(sp.displayName)에게 오늘 글 받기")
        let html = tpl
            .replacingOccurrences(of: "{{DATA_JSON}}", with: json(data))
            .replacingOccurrences(of: "{{STATS_JSON}}", with: json(stats))
            .replacingOccurrences(of: "{{PERSONAS_JSON}}", with: json(personas))
            .replacingOccurrences(of: "{{TODAY}}", with: today)
            .replacingOccurrences(of: "{{HAS_TODAY}}", with: dates.contains(today) ? "true" : "false")
            .replacingOccurrences(of: "{{HAS_FB_ICON}}", with: HTMLRenderer.hasUIFile("fb-sharp.png") ? "true" : "false")
            .replacingOccurrences(of: "{{ART_CLASS}}", with: bodyClass)
            .replacingOccurrences(of: "{{SEAT_PERSONA}}", with: seat.rawValue)
            .replacingOccurrences(of: "{{SEAT_SHEET_URL}}", with: seatSheet)
            .replacingOccurrences(of: "{{SEAT_FRAMES}}", with: seatFrames)
            .replacingOccurrences(of: "{{SEAT_MODE}}", with: generating ? "writing" : "idle")
            .replacingOccurrences(of: "{{SEAT_HINT}}", with: HTMLEscape.escape(hint))
        try? html.write(to: Paths.indexPage, atomically: true, encoding: .utf8)
    }
}

enum HTMLEscape {
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
