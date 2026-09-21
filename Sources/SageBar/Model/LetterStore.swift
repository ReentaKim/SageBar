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
        return text.split(separator: "\n").compactMap { line in
            guard let d = line.data(using: .utf8) else { return nil }
            return try? dec.decode(HistoryEntry.self, from: d)
        }
    }

    /// 같은 날짜 항목은 교체하고 맨 뒤에 덧붙인다 (다시 짓기 시 중복 방지).
    static func appendHistory(_ entry: HistoryEntry) {
        var rows = history().filter { $0.date != entry.date }
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
        for sub in ["styles", "fonts", "seals"] {
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

    static func renderIndex() {
        let tplURL = Paths.resources.appendingPathComponent("templates/index.html")
        guard let tpl = try? String(contentsOf: tplURL, encoding: .utf8) else { return }
        let items = listLetters()
        let rows: String
        if items.isEmpty {
            rows = "<li class=\"empty\">아직 지은 글이 없습니다.</li>"
        } else {
            rows = items.map { info in
                let who = info.persona?.persona.displayName ?? ""
                let name = info.persona?.persona.letterName ?? "조언"
                return "<li><a href=\"\(info.date).html\">\(info.date)</a><span class=\"sub\">\(HTMLEscape.escape(info.subtitle))</span><span class=\"who\">\(who) · \(name)</span></li>"
            }.joined(separator: "\n")
        }
        try? tpl.replacingOccurrences(of: "{{ROWS}}", with: rows)
            .write(to: Paths.indexPage, atomically: true, encoding: .utf8)
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
