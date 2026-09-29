import Foundation

/// Claude 출력(구획 표시된 텍스트)을 편지 구조로 해석하고 HTML 조각으로 바꾼다.
struct ParsedLetter {
    var subtitle: String
    var upper: String
    var lower: String
    var closing: String
    var quoteKorean: String
    var quoteSource: String
    var followup: String = ""        // 지난 조언 점검 (선택)
    var followupMood: String = ""    // pleased(대체로 했다) / stern(대체로 안 했다) / neutral
    var actions: [String] = []       // 오늘 권한 실천 항목 (선택)

    var upperCount: Int { LetterParser.charCount(upper) }
    var lowerCount: Int { LetterParser.charCount(lower) }
    var followupCount: Int { LetterParser.charCount(followup) }
    /// 아침에 읽는 양 — 점검·상편·하편·맺음
    var totalCount: Int { followupCount + upperCount + lowerCount + LetterParser.charCount(closing) }

    func target(_ length: LetterLength) -> Int { length.target(hasFollowup: !followup.isEmpty) }

    /// 목표의 85~120%
    func meetsLength(_ length: LetterLength) -> Bool {
        let t = Double(target(length)), n = Double(totalCount)
        return n >= t * 0.85 && n <= t * 1.2
    }

    /// 목표의 70~150%면 "거의 맞음" — 이때는 몇 분 걸리는 재시도를 하지 않는다
    /// (격언체인 니체처럼 문체상 짧게 나오는 인물이 있다)
    func nearlyMeetsLength(_ length: LetterLength) -> Bool {
        let t = Double(target(length)), n = Double(totalCount)
        return n >= t * 0.7 && n <= t * 1.5
    }

    func isTooLong(_ length: LetterLength) -> Bool { Double(totalCount) > Double(target(length)) * 1.5 }

    /// 본문(점검·상편·하편·맺음)이 근거로 가리킨 발화 번호 — 처음 나온 순서대로, 중복 없이
    var citedRefs: [String] { LetterParser.refIDs(in: [followup, upper, lower, closing].joined(separator: "\n")) }
}

enum LetterParser {
    struct ParseError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// 근거 표식 [[u17]] (여럿이면 [[u3, u8]]). 앞의 공백까지 한 덩이로 잡아, 떼어 내면 문장이 붙는다.
    static let refPattern = #"\s*\[\[\s*(u\d+(?:\s*[,，·/ ]\s*u\d+)*)\s*\]\]"#

    static func refIDs(inMarker body: String) -> [String] {
        body.split(whereSeparator: { ",，·/ ".contains($0) }).map(String.init).filter { !$0.isEmpty }
    }

    /// 글에 나온 근거 번호들 — 처음 나온 순서대로, 중복 없이
    static func refIDs(in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: refPattern) else { return [] }
        var seen = Set<String>(), out: [String] = []
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(m.range(at: 1), in: text) else { continue }
            for id in refIDs(inMarker: String(text[r])) where seen.insert(id).inserted { out.append(id) }
        }
        return out
    }

    static func stripRefs(_ text: String) -> String {
        text.replacingOccurrences(of: refPattern, with: "", options: .regularExpression)
    }

    /// 표식을 위첨자 번호로. refs(발화 번호 → 편지 안 번호)에 없는 번호는 버리고, 하나도 안 남으면 표식째 없앤다.
    static func refsToHTML(_ html: String, refs: [String: Int]) -> String {
        guard let re = try? NSRegularExpression(pattern: refPattern) else { return html }
        var out = "", last = html.startIndex
        for m in re.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let whole = Range(m.range, in: html), let body = Range(m.range(at: 1), in: html) else { continue }
            out += html[last..<whole.lowerBound]
            let nums = refIDs(inMarker: String(html[body])).compactMap { refs[$0] }
            if !nums.isEmpty {
                out += "<sup class=\"sage-ref\">" + nums.map { "<a href=\"#ev-\($0)\">\($0)</a>" }.joined(separator: ",") + "</sup>"
            }
            last = whole.upperBound
        }
        return out + html[last...]
    }

    /// 공백류를 제외한 문자 수 (근거 표식은 세지 않는다)
    static func charCount(_ text: String) -> Int {
        stripRefs(text).unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
    }

    /// 한자(CJK 통합 한자) 글자 수 — 0이어야 정상
    static func hanjaCount(_ text: String) -> Int {
        text.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }.count
    }

    static func firstMatch(_ pattern: String, in text: String, options: NSRegularExpression.Options = []) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func section(_ name: String, next: [String], in text: String) -> String {
        let pattern: String
        if next.isEmpty {
            pattern = "---\(name)---\\s*([\\s\\S]*)\\z"
        } else {
            let look = next.map { "---\($0)---" }.joined(separator: "|")
            pattern = "---\(name)---\\s*([\\s\\S]*?)(?=\(look))"
        }
        return firstMatch(pattern, in: text) ?? ""
    }

    static func parse(_ raw: String) throws -> ParsedLetter {
        // 코드블록 울타리가 섞여 오면 벗긴다
        let text = raw.replacingOccurrences(of: "```", with: "")
        let subtitle = stripRefs(firstMatch("^SUBTITLE:\\s*(.+)$", in: text, options: .anchorsMatchLines) ?? "")
        let followupRaw = section("FOLLOWUP", next: ["UPPER"], in: text)
        let followupMood = firstMatch("^FOLLOWUP_MOOD:\\s*(\\w+)", in: followupRaw, options: .anchorsMatchLines)?.lowercased() ?? ""
        let followup = followupRaw.replacingOccurrences(of: "(?m)^FOLLOWUP_MOOD:.*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = section("UPPER", next: ["LOWER", "CLOSING"], in: text)
        let lower = section("LOWER", next: ["CLOSING"], in: text)
        let hasActions = text.contains("---ACTIONS---")
        let tail = section("CLOSING", next: [], in: text)            // CLOSING 이후 전부 (인용구가 어디 있든 찾기 위해)
        let closingBlock = hasActions ? section("CLOSING", next: ["ACTIONS"], in: text) : tail
        let actionsBlock = hasActions ? section("ACTIONS", next: [], in: text) : ""
        let actions: [String] = actionsBlock.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.replacingOccurrences(of: "^([-•*]|\\d+[.)])\\s*", with: "", options: .regularExpression) }
            .map(stripRefs)
            .filter { !$0.isEmpty && !$0.hasPrefix("QUOTE_") && !$0.hasPrefix("(") }
            .prefix(3).map { String($0) }

        let quoteKorean = stripRefs(firstMatch("^QUOTE_KOREAN:\\s*(.+)$", in: tail, options: .anchorsMatchLines) ?? "")
        let quoteSource = stripRefs(firstMatch("^QUOTE_SOURCE:\\s*(.+)$", in: tail, options: .anchorsMatchLines) ?? "")
        var closing = closingBlock
        for key in ["QUOTE_KOREAN", "QUOTE_SOURCE"] {
            closing = closing.replacingOccurrences(of: "(?m)^\(key):.*$", with: "", options: .regularExpression)
        }
        closing = closing.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !upper.isEmpty, !lower.isEmpty else {
            throw ParseError(message: "구획 표시(---UPPER---/---LOWER---)를 찾지 못했습니다.")
        }
        return ParsedLetter(subtitle: subtitle, upper: upper, lower: lower, closing: closing,
                            quoteKorean: quoteKorean, quoteSource: quoteSource,
                            followup: followup, followupMood: followupMood, actions: actions)
    }

    /// 이스케이프된 텍스트 안의 **강조**를 <strong>으로
    static func inlineMarkdown(_ escaped: String) -> String {
        escaped.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
    }

    /// 빈 줄로 구분된 문단을 <p>로, "### "로 시작하는 줄을 소제목으로.
    /// 번호 매긴 줄(니체의 격언 등)은 각각 별도 문단으로 취급한다. 근거 표식은 문단에서는 위첨자로, 소제목에서는 뗀다.
    static func paragraphsToHTML(_ block: String, refs: [String: Int] = [:]) -> String {
        var out: [String] = []
        let chunks = block.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n \n") }
        for rawChunk in chunks {
            let chunk = rawChunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if chunk.isEmpty { continue }
            if chunk.hasPrefix("### ") || chunk.hasPrefix("## ") {
                let title = stripRefs(chunk.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                out.append("<h3 class=\"sage-h3\"><span class=\"dot\">●</span>\(inlineMarkdown(HTMLEscape.escape(title)))</h3>")
            } else {
                // 소제목이 문단과 한 덩이로 붙어 온 경우 분리
                let lines = chunk.components(separatedBy: "\n")
                var buffer: [String] = []
                func flush() {
                    if buffer.isEmpty { return }
                    let escaped = HTMLEscape.escape(buffer.joined(separator: "\n")).replacingOccurrences(of: "\n", with: "<br>")
                    out.append("<p>\(refsToHTML(inlineMarkdown(escaped), refs: refs))</p>")
                    buffer.removeAll()
                }
                for line in lines {
                    if line.hasPrefix("### ") || line.hasPrefix("## ") {
                        flush()
                        let title = stripRefs(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                        out.append("<h3 class=\"sage-h3\"><span class=\"dot\">●</span>\(inlineMarkdown(HTMLEscape.escape(title)))</h3>")
                    } else if line.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil {
                        flush()
                        buffer.append(line)
                    } else {
                        buffer.append(line)
                    }
                }
                flush()
            }
        }
        return out.joined(separator: "\n")
    }
}
