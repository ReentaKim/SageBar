import Foundation

/// 한 편을 짓는 블로킹 파이프라인 (인물지 확인 → 재료 → claude → 파싱 → 렌더).
/// UI와 무관하므로 헤드리스 CLI와 앱 엔진이 함께 쓴다.
struct LetterGenerator {
    var model: ClaudeModel
    var length: LetterLength
    var recentDays: Int
    /// 단계가 바뀔 때마다 불린다 (어느 스레드에서든)
    var onStage: (String) -> Void = { _ in }

    struct Result {
        let url: URL
        let parsed: ParsedLetter
        let hanjaCount: Int
    }

    func generate(persona id: PersonaID, date: Date) throws -> Result {
        let persona = id.persona
        let dateStr = LetterStore.dateString(date)
        LetterStore.log("[\(id.rawValue)] 생성 시작 (모델: \(model.rawValue), 길이: \(length.rawValue))")

        // 1) 인물지 없으면 먼저 짓는다
        if !ProfileBuilder.exists {
            onStage("인물지를 짓는 중")
            try ProfileBuilder.build(model: model)
        }

        // 2) 재료
        onStage("최근 대화를 읽는 중")
        let recent = ConversationExtractor.recentMarkdown(days: recentDays)
        try? recent.write(to: Paths.recent, atomically: true, encoding: .utf8)
        let profile = try String(contentsOf: Paths.profile, encoding: .utf8)
        let topics = LetterStore.recentTopics()

        // 3) 짓기 (분량 미달이면 1회 재시도)
        onStage("\(persona.displayName)이(가) 글을 짓는 중")
        let prompt = PromptBuilder.letterPrompt(persona: persona, profile: profile, recent: recent,
                                                recentTopics: topics, date: date, length: length, recentDays: recentDays)
        var raw = try ClaudeCLI.run(prompt: prompt, model: model)
        try? raw.write(to: LetterStore.rawURL(for: dateStr), atomically: true, encoding: .utf8)
        var parsed = try LetterParser.parse(raw)

        if !parsed.meetsLength(length) {
            LetterStore.log("[\(id.rawValue)] 분량 미달 (\(parsed.upperCount)/\(parsed.lowerCount)) — 재시도")
            onStage("분량이 모자라 다시 짓는 중")
            if let retryRaw = try? ClaudeCLI.run(prompt: prompt + PromptBuilder.retryNote(length: length), model: model),
               let retryParsed = try? LetterParser.parse(retryRaw),
               retryParsed.totalCount > parsed.totalCount {
                raw = retryRaw
                parsed = retryParsed
                try? raw.write(to: LetterStore.rawURL(for: dateStr), atomically: true, encoding: .utf8)
            }
        }

        let hanja = LetterParser.hanjaCount(parsed.upper + parsed.lower + parsed.closing + parsed.subtitle)
        if hanja > 0 { LetterStore.log("[\(id.rawValue)] 경고: 한자 \(hanja)자 포함") }

        // 4) 엮기
        onStage("두루마리에 옮기는 중")
        let url = try HTMLRenderer.render(letter: parsed, persona: persona, date: date, model: model)
        LetterStore.appendHistory(HistoryEntry(date: dateStr, persona: id.rawValue, subtitle: parsed.subtitle))
        LetterStore.renderIndex()
        LetterStore.log("[\(id.rawValue)] 완료: \(url.lastPathComponent) (\(parsed.upperCount)/\(parsed.lowerCount)/\(parsed.totalCount)자, 분량 \(parsed.meetsLength(length) ? "충족" : "미달"))")

        // 5) 인물지가 오래됐으면 뒤에서 조용히 갱신
        if ProfileBuilder.isStale {
            let m = model
            DispatchQueue.global(qos: .background).async {
                do { try ProfileBuilder.build(model: m) } catch { LetterStore.log("[profile] 갱신 실패: \(error.localizedDescription)") }
            }
        }
        return Result(url: url, parsed: parsed, hanjaCount: hanja)
    }
}
