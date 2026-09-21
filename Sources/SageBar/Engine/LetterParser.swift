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
    var totalCount: Int { upperCount + lowerCount + LetterParser.charCount(closing) }

    func meetsLength(_ length: LetterLength) -> Bool {
        upperCount >= length.minUpper && lowerCount >= length.minLower
    }

    /// 기준의 75% 이상이면 "거의 충족" — 이때는 3분 넘게 걸리는 재시도를 하지 않는다
    /// (격언체인 니체처럼 문체상 짧게 나오는 인물이 있다)
    func nearlyMeetsLength(_ length: LetterLength) -> Bool {
        Double(upperCount) >= Double(length.minUpper) * 0.75 && Double(lowerCount) >= Double(length.minLower) * 0.75
    }
}

enum LetterParser {
    struct ParseError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// 공백류를 제외한 문자 수
    static func charCount(_ text: String) -> Int {
        text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
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
        let subtitle = firstMatch("^SUBTITLE:\\s*(.+)$", in: text, options: .anchorsMatchLines) ?? ""
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
            .filter { !$0.isEmpty && !$0.hasPrefix("QUOTE_") && !$0.hasPrefix("(") }
            .prefix(3).map { String($0) }

        let quoteKorean = firstMatch("^QUOTE_KOREAN:\\s*(.+)$", in: tail, options: .anchorsMatchLines) ?? ""
        let quoteSource = firstMatch("^QUOTE_SOURCE:\\s*(.+)$", in: tail, options: .anchorsMatchLines) ?? ""
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
    /// 번호 매긴 줄(니체의 격언 등)은 각각 별도 문단으로 취급한다.
    static func paragraphsToHTML(_ block: String) -> String {
        var out: [String] = []
        let chunks = block.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n \n") }
        for rawChunk in chunks {
            let chunk = rawChunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if chunk.isEmpty { continue }
            if chunk.hasPrefix("### ") || chunk.hasPrefix("## ") {
                let title = chunk.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                out.append("<h3 class=\"sage-h3\"><span class=\"dot\">●</span>\(inlineMarkdown(HTMLEscape.escape(title)))</h3>")
            } else {
                // 소제목이 문단과 한 덩이로 붙어 온 경우 분리
                let lines = chunk.components(separatedBy: "\n")
                var buffer: [String] = []
                func flush() {
                    if buffer.isEmpty { return }
                    let escaped = HTMLEscape.escape(buffer.joined(separator: "\n")).replacingOccurrences(of: "\n", with: "<br>")
                    out.append("<p>\(inlineMarkdown(escaped))</p>")
                    buffer.removeAll()
                }
                for line in lines {
                    if line.hasPrefix("### ") || line.hasPrefix("## ") {
                        flush()
                        let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
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
