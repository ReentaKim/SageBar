import Foundation

/// ~/.claude/projects/*/*.jsonl 에서 사용자가 직접 입력한 말만 골라낸다.
/// (도구·스킬이 주입한 본문, 부속 세션은 제외)
enum ConversationExtractor {
    struct Utterance {
        let timestamp: String
        let project: String
        let folder: String
        let text: String
    }

    static let projectsDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/projects")
    static let plansDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/plans")

    static let skipPrefixes: [String] = [
        "<", "[Request interrupted", "Another Claude session sent a message",
        "Base directory for this skill", "## Context Usage", "# Claude in Chrome",
        "# Update Config Skill", "# Fewer Permission Prompts", "(Re-invocation of",
    ]
    static let maxCharsPerMessage = 500

    static var hasAnyHistory: Bool { !jsonlFiles().isEmpty }

    /// 프로젝트 폴더들. SageBar 자신이 claude -p 를 부른 세션(작업 폴더 = Paths.logs)은 사용자 발화가 아니라 뺀다.
    static func projectDirs() -> [URL] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return [] }
        let ownDir = mangle(Paths.logs.path)
        return projects.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && $0.lastPathComponent != ownDir
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 읽을 대화 파일. 설정에서 뺀 프로젝트는 건너뛰고, since가 있으면 그보다 오래 손대지 않은 파일은 열지 않는다.
    static func jsonlFiles(excluding excluded: Set<String> = AppSettings.excludedProjects, modifiedSince since: Date? = nil) -> [URL] {
        let fm = FileManager.default
        var out: [URL] = []
        for p in projectDirs() where !excluded.contains(p.lastPathComponent) {
            let files = (try? fm.contentsOfDirectory(at: p, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            out += files.filter { f in
                guard f.pathExtension == "jsonl" else { return false }
                guard let since else { return true }
                let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantFuture
                return m >= since
            }
        }
        return out
    }

    struct ProjectSummary: Identifiable {
        let folder: String       // ~/.claude/projects 아래 폴더 이름 (제외 목록의 키)
        let name: String         // 보여 줄 이름
        let recentCount: Int     // 최근 N일 발화 수
        let lastDate: String     // 마지막 발화 날짜
        var id: String { folder }
    }

    /// 설정 화면용: 프로젝트마다 최근 발화 수와 마지막 날짜. 제외 여부와 상관없이 대화 파일이 있는 폴더는 전부 보여 준다.
    static func projectSummaries(days: Int = AppSettings.recentDays) -> [ProjectSummary] {
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(days) * 86400))
        // 대화 파일이 하나도 없는 폴더(memory만 있는 등)는 읽을 것이 없으니 목록에서 뺀다
        let files = jsonlFiles(excluding: [])
        let (rows, roots) = scan(files)
        var byFolder: [String: [Utterance]] = [:]
        for r in rows { byFolder[r.folder, default: []].append(r) }
        let withFiles = Set(files.map { $0.deletingLastPathComponent().lastPathComponent })
        return projectDirs().filter { withFiles.contains($0.lastPathComponent) }.map { dir in
            let items = byFolder[dir.lastPathComponent] ?? []
            return ProjectSummary(folder: dir.lastPathComponent,
                                  name: projectName(folder: dir.lastPathComponent, root: roots[dir.lastPathComponent]),
                                  recentCount: items.filter { $0.timestamp >= cutoff }.count,
                                  lastDate: items.last.map { String($0.timestamp.prefix(10)) } ?? "")
        }
        .sorted { ($0.lastDate, $0.name) > ($1.lastDate, $1.name) }
    }

    /// Claude Code가 작업 경로로 폴더 이름을 만드는 방식: 영숫자 아닌 글자(/ . _ 공백 한글 등)를 모두 "-"로.
    static func mangle(_ path: String) -> String {
        path.replacingOccurrences(of: "[^A-Za-z0-9]", with: "-", options: .regularExpression)
    }

    /// 대화 기록 줄에 적힌 작업 경로(cwd)들 가운데 폴더 이름과 똑같이 바뀌는 것이 그 프로젝트의 뿌리다.
    /// (세션 안에서 하위 폴더로 옮겨 다니면 cwd가 여럿이 된다.) 맞는 것이 없으면 — 작업 폴더 이름을 나중에 바꾼 경우 —
    /// 가장 짧은 경로를 쓴다.
    static func pickRoot(folder: String, candidates: some Collection<String>) -> String? {
        candidates.first { mangle($0) == folder }
            ?? candidates.min { ($0.count, $0) < ($1.count, $1) }
    }

    /// 보여 줄 이름: 홈 아래면 "~/…", 아니면 절대 경로 그대로
    static func displayName(root: String, home: String = NSHomeDirectory()) -> String {
        if root == home { return "~" }
        if root.hasPrefix(home + "/") { return "~" + root.dropFirst(home.count) }
        return root
    }

    /// 실제 경로를 찾았으면 그것을, 못 찾았으면 폴더 이름에서 홈 부분만 뗀 것을
    static func projectName(folder: String, root: String?) -> String {
        root.map { displayName(root: $0) } ?? cleanProjectName(folder)
    }

    /// "-Users-me-work-foo" → "work-foo" (홈 디렉터리 부분을 떼어 낸다). 실제 경로(cwd)를 못 찾았을 때의 대체 이름.
    static func cleanProjectName(_ dirname: String, home: String = NSHomeDirectory()) -> String {
        let homePrefix = mangle(home)
        guard dirname.hasPrefix(homePrefix) else { return dirname }
        let rest = dirname.dropFirst(homePrefix.count).drop { $0 == "-" }
        return rest.isEmpty ? "~" : String(rest)
    }

    static func extractTexts(_ content: Any?) -> [String] {
        if let s = content as? String { return [s] }
        if let arr = content as? [[String: Any]] {
            return arr.compactMap { block in
                (block["type"] as? String) == "text" ? (block["text"] as? String) : nil
            }
        }
        return []
    }

    static func shouldSkip(_ t: String) -> Bool {
        if t.isEmpty { return true }
        return skipPrefixes.contains { t.hasPrefix($0) }
    }

    static func shrinkImageTags(_ t: String) -> String {
        t.replacingOccurrences(of: #"\[Image:[^\]]*\]"#, with: "(이미지 첨부)", options: .regularExpression)
    }

    static func truncate(_ t: String) -> String {
        let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > maxCharsPerMessage {
            return String(s.prefix(maxCharsPerMessage)) + " …(총 \(s.count)자 중 절단)"
        }
        return s
    }

    static func allUtterances() -> [Utterance] { utterances(in: jsonlFiles()) }

    static func utterances(in files: [URL]) -> [Utterance] { scan(files).rows }

    /// 발화를 모으면서 폴더마다 실제 작업 경로(뿌리)도 찾는다. 발화의 project는 뿌리를 찾았으면 "~/…" 경로로.
    static func scan(_ files: [URL]) -> (rows: [Utterance], roots: [String: String]) {
        var rows: [Utterance] = []
        var cwds: [String: Set<String>] = [:]
        for file in files {
            let folder = file.deletingLastPathComponent().lastPathComponent
            guard let data = try? Data(contentsOf: file) else { continue }
            let text = String(decoding: data, as: UTF8.self)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let d = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
                if let cwd = obj["cwd"] as? String, !cwd.isEmpty { cwds[folder, default: []].insert(cwd) }
                guard (obj["type"] as? String) == "user",
                      (obj["isSidechain"] as? Bool) != true else { continue }
                let msg = obj["message"] as? [String: Any] ?? [:]
                let ts = obj["timestamp"] as? String ?? ""
                for raw in extractTexts(msg["content"]) {
                    let t = shrinkImageTags(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                    if shouldSkip(t) { continue }
                    let cut = truncate(t)
                    if !cut.isEmpty { rows.append(Utterance(timestamp: ts, project: "", folder: folder, text: cut)) }
                }
            }
        }
        var roots: [String: String] = [:]
        for (folder, set) in cwds { roots[folder] = pickRoot(folder: folder, candidates: set) }
        rows = rows.map { Utterance(timestamp: $0.timestamp, project: projectName(folder: $0.folder, root: roots[$0.folder]),
                                    folder: $0.folder, text: $0.text) }
        rows.sort { $0.timestamp < $1.timestamp }
        return (rows, roots)
    }

    struct PlanSummary { let mtime: String; let file: String; let title: String; let firstParagraph: String }

    static func loadPlans() -> [PlanSummary] {
        guard AppSettings.includePlans else { return [] }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: plansDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        var out: [PlanSummary] = []
        for f in files.filter({ $0.pathExtension == "md" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let content = try? String(contentsOf: f, encoding: .utf8) else { continue }
            var title = ""
            var para: [String] = []
            for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
                let s = line.trimmingCharacters(in: .whitespaces)
                if title.isEmpty, s.hasPrefix("#") {
                    title = s.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                    continue
                }
                if !title.isEmpty, !s.isEmpty { para.append(s) }
                else if !title.isEmpty, !para.isEmpty { break }
            }
            guard !title.isEmpty else { continue }
            let mdate = (try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
            out.append(PlanSummary(mtime: LetterStore.dateString(mdate), file: f.lastPathComponent,
                                   title: title, firstParagraph: String(para.joined(separator: " ").prefix(300))))
        }
        return out
    }

    static func oneLine(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// 최근 N일치 발화를 시간순 마크다운으로.
    static func recentMarkdown(days: Int) -> String {
        let since = Date().addingTimeInterval(-Double(days) * 86400)
        let cutoff = ISO8601DateFormatter().string(from: since)
        let rows = utterances(in: jsonlFiles(modifiedSince: since)).filter { $0.timestamp >= cutoff }
        var out = "# 최근 \(days)일 발화 발췌 (\(rows.count)건)\n\n"
        for r in rows {
            let date = r.timestamp.isEmpty ? "????-??-??" : String(r.timestamp.prefix(10))
            out += "- [\(date) · \(r.project)] \(oneLine(r.text))\n"
        }
        let plans = loadPlans()
        if !plans.isEmpty {
            out += "\n# 계획 문서 (\(plans.count)건)\n\n"
            for p in plans { out += "- [\(p.mtime) · \(p.file)] \(p.title) — \(p.firstParagraph)\n" }
        }
        return out
    }

    /// 전체 발화를 프로젝트별로 묶은 마크다운 (인물지 작성용). 너무 길면 뒤쪽(최근)을 남기고 자른다.
    static func allMarkdown(maxChars: Int = 350_000) -> String {
        let rows = allUtterances()
        var byProject: [String: [Utterance]] = [:]
        for r in rows { byProject[r.project, default: []].append(r) }
        var out = "# 전체 발화 (\(rows.count)건, \(byProject.count)개 프로젝트)\n"
        for project in byProject.keys.sorted() {
            let items = byProject[project]!
            out += "\n## \(project) (\(items.count)건)\n\n"
            for r in items {
                let date = r.timestamp.isEmpty ? "????-??-??" : String(r.timestamp.prefix(10))
                out += "- [\(date)] \(oneLine(r.text))\n"
            }
        }
        let plans = loadPlans()
        if !plans.isEmpty {
            out += "\n## 계획 문서 (\(plans.count)건)\n\n"
            for p in plans { out += "- [\(p.mtime) · \(p.file)] \(p.title) — \(p.firstParagraph)\n" }
        }
        if out.count > maxChars {
            out = "(앞부분 생략 — 전체 \(out.count)자 중 최근 \(maxChars)자)\n" + String(out.suffix(maxChars))
        }
        return out
    }
}
