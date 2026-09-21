import Foundation

/// 해석된 편지를 인물 테마가 적용된 HTML로 엮어 letters/YYYY-MM-DD.html 에 쓴다.
enum HTMLRenderer {
    static let stems = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"]
    static let branches = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"]

    static func ganjiYear(_ y: Int) -> String {
        "\(stems[((y - 4) % 10 + 10) % 10])\(branches[((y - 4) % 12 + 12) % 12])년"
    }

    static func dateLine(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let wd = PromptBuilder.weekdayNames[Calendar.current.component(.weekday, from: date) - 1]
        return "\(c.year!)년 \(c.month!)월 \(c.day!)일 (\(wd))"
    }

    static func loadResource(_ relative: String) -> String? {
        try? String(contentsOf: Paths.resources.appendingPathComponent(relative), encoding: .utf8)
    }

    @discardableResult
    static func render(letter: ParsedLetter, persona: Persona, date: Date, model: ClaudeModel,
                       outputURL: URL? = nil) throws -> URL {
        guard let template = loadResource("templates/letter.html") else {
            throw LetterParser.ParseError(message: "템플릿(templates/letter.html)을 찾을 수 없습니다.")
        }
        let dateStr = LetterStore.dateString(date)
        let outURL = outputURL ?? LetterStore.letterURL(for: dateStr)
        let year = Calendar.current.component(.year, from: date)
        let seal = loadResource("seals/\(persona.id.rawValue).svg") ?? ""

        let previous = LetterStore.listLetters().map(\.date).filter { $0 < dateStr }.first
        let prevLink = previous.map { "<a class=\"sage-btn\" href=\"\($0).html\">◀ 지난 글 보기</a>" }
            ?? "<span class=\"sage-btn sage-btn-disabled\">◀ 지난 글 보기</span>"

        let replacements: [String: String] = [
            "{{PERSONA_ID}}": persona.id.rawValue,
            "{{PERSONA_NAME}}": HTMLEscape.escape(persona.fullTitle),
            "{{LETTER_NAME}}": HTMLEscape.escape(persona.letterName),
            "{{SUBTITLE}}": HTMLEscape.escape(letter.subtitle),
            "{{DATE_LINE}}": dateLine(date),
            "{{GANJI_LINE}}": persona.showsGanji ? " · \(ganjiYear(year))" : "",
            "{{GREETING}}": HTMLEscape.escape(persona.greeting),
            "{{UPPER_MARK}}": HTMLEscape.escape(persona.upperMark),
            "{{UPPER_TITLE}}": HTMLEscape.escape(persona.upperTitle),
            "{{LOWER_MARK}}": HTMLEscape.escape(persona.lowerMark),
            "{{LOWER_TITLE}}": HTMLEscape.escape(persona.lowerTitle),
            "{{UPPER_HTML}}": LetterParser.paragraphsToHTML(letter.upper),
            "{{LOWER_HTML}}": LetterParser.paragraphsToHTML(letter.lower),
            "{{CLOSING_HTML}}": LetterParser.paragraphsToHTML(letter.closing),
            "{{QUOTE_KOREAN}}": HTMLEscape.escape(letter.quoteKorean),
            "{{QUOTE_SOURCE}}": HTMLEscape.escape(letter.quoteSource),
            "{{SIGNOFF}}": HTMLEscape.escape(persona.signoff),
            "{{SEAL_SVG}}": seal,
            "{{PREV_LINK}}": prevLink,
            "{{UPPER_COUNT}}": formatNumber(letter.upperCount),
            "{{LOWER_COUNT}}": formatNumber(letter.lowerCount),
            "{{TOTAL_COUNT}}": formatNumber(letter.totalCount),
            "{{MODEL}}": model.rawValue,
            "{{AVATAR_HTML}}": avatarHTML(persona),
        ]
        var html = template
        for (k, v) in replacements { html = html.replacingOccurrences(of: k, with: v) }
        try html.write(to: outURL, atomically: true, encoding: .utf8)
        return outURL
    }

    // MARK: 도트 캐릭터 (Resources/characters/<id>/ 에 파일이 있을 때만 — 없으면 빈 문자열로 폴백)

    static func hasCharacterFile(_ persona: Persona, _ name: String) -> Bool {
        FileManager.default.fileExists(atPath: Paths.resources.appendingPathComponent("characters/\(persona.id.rawValue)/\(name)").path)
    }

    /// 편지 머리: 말하는 얼굴(3프레임) → 몇 번 반복 후 입 닫힌 초상으로 멈춤
    static func avatarHTML(_ persona: Persona) -> String {
        guard hasCharacterFile(persona, "talking.png") || hasCharacterFile(persona, "portrait.png") else { return "" }
        let base = "../assets/characters/\(persona.id.rawValue)"
        if hasCharacterFile(persona, "talking.png") {
            return "<div class=\"sage-avatar\" aria-hidden=\"true\"><div class=\"sage-talk\" style=\"background-image:url('\(base)/talking.png')\"></div></div>"
        }
        return "<div class=\"sage-avatar\" aria-hidden=\"true\"><img src=\"\(base)/portrait.png\" alt=\"\"></div>"
    }

    /// 대기·실패 화면: 글 쓰는 모습(4프레임) 또는 숨쉬기(2프레임)
    static func spriteHTML(_ persona: Persona, writing: Bool) -> String {
        let name = writing ? "writing.png" : "idle.png"
        guard hasCharacterFile(persona, name) else { return "" }
        let cls = writing ? "sage-sprite sage-writing" : "sage-sprite sage-idle"
        return "<div class=\"\(cls)\" aria-hidden=\"true\" style=\"background-image:url('../assets/characters/\(persona.id.rawValue)/\(name)')\"></div>"
    }

    static func portraitThumbHTML(_ persona: Persona) -> String {
        guard hasCharacterFile(persona, "portrait.png") else { return "" }
        return "<img class=\"sage-thumb\" src=\"../assets/characters/\(persona.id.rawValue)/portrait.png\" alt=\"\">"
    }

    static func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// 대기·실패 화면. 편지 폴더에 써서 같은 방식으로 띄운다.
    static func writeStatusPage(persona: Persona, title: String, line: String, hint: String,
                                animated: Bool, extra: String = "") -> URL? {
        guard let tpl = loadResource("templates/waiting.html") else { return nil }
        let html = tpl
            .replacingOccurrences(of: "{{TITLE}}", with: HTMLEscape.escape(title))
            .replacingOccurrences(of: "{{LINE}}", with: HTMLEscape.escape(line))
            .replacingOccurrences(of: "{{HINT}}", with: HTMLEscape.escape(hint))
            .replacingOccurrences(of: "{{DOTS_CLASS}}", with: animated ? "dots" : "")
            .replacingOccurrences(of: "{{EXTRA}}", with: extra)
            .replacingOccurrences(of: "{{SPRITE_HTML}}", with: spriteHTML(persona, writing: animated))
            .replacingOccurrences(of: "{{PERSONA_ID}}", with: persona.id.rawValue)
            .replacingOccurrences(of: "{{ASSETS}}", with: "../assets")
        try? html.write(to: Paths.waitingPage, atomically: true, encoding: .utf8)
        return Paths.waitingPage
    }

    /// 생성이 끝내 실패했을 때 그날 자리에 남기는 예비 글
    static func writeFallbackLetter(persona: Persona, date: Date, reason: String) -> URL? {
        guard let tpl = loadResource("templates/waiting.html") else { return nil }
        let dateStr = LetterStore.dateString(date)
        let html = tpl
            .replacingOccurrences(of: "{{TITLE}}", with: HTMLEscape.escape(persona.failTitle))
            .replacingOccurrences(of: "{{LINE}}", with: HTMLEscape.escape(persona.failLine))
            .replacingOccurrences(of: "{{HINT}}", with: "메뉴바의 SageBar 아이콘 → \"지금 새로 짓기\"로 다시 시도할 수 있습니다.")
            .replacingOccurrences(of: "{{DOTS_CLASS}}", with: "")
            .replacingOccurrences(of: "{{EXTRA}}", with: "<div class=\"err\">\(HTMLEscape.escape(reason))</div>")
            .replacingOccurrences(of: "{{SPRITE_HTML}}", with: spriteHTML(persona, writing: false))
            .replacingOccurrences(of: "{{PERSONA_ID}}", with: persona.id.rawValue)
            .replacingOccurrences(of: "{{ASSETS}}", with: "../assets")
        let url = LetterStore.letterURL(for: dateStr)
        try? html.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
