import Foundation

/// ~/.claude/projects/*/*.jsonl 에서 사용자가 직접 입력한 말만 골라낸다.
/// (도구·스킬이 주입한 본문, 부속 세션은 제외)
enum ConversationExtractor {
    struct Utterance {
        let timestamp: String
        let project: String
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

    static func jsonlFiles() -> [URL] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return [] }
        var out: [URL] = []
        for p in projects {
            guard (try? p.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let files = (try? fm.contentsOfDirectory(at: p, includingPropertiesForKeys: nil)) ?? []
            out += files.filter { $0.pathExtension == "jsonl" }
        }
        return out
    }

    /// "-Users-me-work-foo" → "work-foo" (홈 디렉터리 부분을 떼어 낸다)
    static func cleanProjectName(_ dirname: String) -> String {
        let homePrefix = NSHomeDirectory().replacingOccurrences(of: "/", with: "-") + "-"
        if dirname.hasPrefix(homePrefix) { return String(dirname.dropFirst(homePrefix.count)) }
        return dirname
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

    static func allUtterances() -> [Utterance] {
        var rows: [Utterance] = []
        for file in jsonlFiles() {
            let project = cleanProjectName(file.deletingLastPathComponent().lastPathComponent)
            guard let data = try? Data(contentsOf: file) else { continue }
            let text = String(decoding: data, as: UTF8.self)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let d = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                      (obj["type"] as? String) == "user",
                      (obj["isSidechain"] as? Bool) != true else { continue }
                let msg = obj["message"] as? [String: Any] ?? [:]
                let ts = obj["timestamp"] as? String ?? ""
                for raw in extractTexts(msg["content"]) {
                    let t = shrinkImageTags(raw.trimmingCharacters(in: .whitespacesAndNewlines))
                    if shouldSkip(t) { continue }
                    let cut = truncate(t)
                    if !cut.isEmpty { rows.append(Utterance(timestamp: ts, project: project, text: cut)) }
                }
            }
        }
        rows.sort { $0.timestamp < $1.timestamp }
        return rows
    }

    struct PlanSummary { let mtime: String; let file: String; let title: String; let firstParagraph: String }

    static func loadPlans() -> [PlanSummary] {
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
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(days) * 86400))
        let rows = allUtterances().filter { $0.timestamp >= cutoff }
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
