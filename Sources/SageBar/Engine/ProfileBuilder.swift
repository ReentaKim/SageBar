import Foundation

/// 인물지(profile.md) — 사용자의 대화 기록에서 뽑아낸 "이 사람은 누구이고 무엇을 하는가".
/// 첫 실행 때 처음부터 짓고, 이후 매주 최근 대화를 더해 갱신한다.
enum ProfileBuilder {
    static let structureGuide = """
    ## 1. 신원과 소임 — 이름(대화에서 확인될 때만), 직함, 속한 조직, 맡은 일
    ## 2. 다스리는 땅 — 다루는 사업·제품·분야
    ## 3. 벌이는 일 — 현재 진행 중인 프로젝트와 각 국면
    ## 4. 거느리고 섬기는 사람 — 함께 일하는 사람·관계 (직함 위주, 개인정보 최소화)
    ## 5. 연장(AI 코딩 도구)을 쓰는 버릇 — ### 강점 / ### 약점 (실제 발화를 인용 근거로)
    ## 6. 되풀이되는 고민 — 반복해 나타나는 걱정·방향 고민
    """

    static let commonRules = """
    원칙:
    - 대화에서 확인된 사실만 쓴다. 지어내지 않는다. 추측이 필요하면 "(추정)"이라고 표시한다.
    - 이름은 대화에서 본인이 직접 밝힌 경우에만 적고, 그렇지 않으면 "그대"라고만 부른다.
      전화번호·주민번호·계좌·비밀번호·주소 같은 민감 정보는 어떤 경우에도 적지 않는다.
    - 전체 3,000~4,500자 분량.
    - 출력은 오직 마크다운 인물지 전문뿐이다. 다른 설명, 인사말, 코드블록 표시를 덧붙이지 마라.
    - **한자(漢字) 글자를 단 한 글자도 쓰지 마라.** 문서 제목도 "인물지"로 한글만 쓴다.
    - 첫 줄은 "# 인물지" 로 시작하고, 둘째 줄에 "> 마지막 전면 작성: (오늘 날짜)" 를 적는다.
    """

    static func initialPrompt(all: String, today: String) -> String {
        """
        당신은 한 사람의 인물지를 처음 작성하는 사관이다.
        아래는 그 사람이 AI 코딩 도구(Claude Code)와 나눈 전체 대화에서 그 사람이 직접 입력한 말만
        시간순·프로젝트별로 발췌한 것이다. 이것을 근거로, 앞으로 매일 아침 이 사람에게 조언을 지을
        재료가 되는 인물지를 작성하라.

        문서 구조(이 여섯 절을 그대로 쓴다):
        \(structureGuide)

        \(commonRules)
        오늘 날짜: \(today)

        ────────── 전체 대화 발췌 ──────────
        \(all)
        """
    }

    static func updatePrompt(existing: String, all: String, today: String) -> String {
        """
        당신은 한 사람에 대한 인물지를 관리하는 사관이다.
        아래에 기존 인물지와, 그 사람이 AI 코딩 도구와 나눈 전체 대화 발췌가 있다. 이 둘을 근거로
        인물지를 갱신한 전문을 새로 작성하라.

        - 기존 인물지의 구조(1~6절)를 유지한다.
        - 새 대화에서 확인된 사실만 반영한다. 이미 끝난 일은 국면을 갱신하거나 정리하고,
          새로 시작된 일은 추가한다.
        - "5. 연장을 쓰는 버릇"의 강점/약점은 실제 발화를 인용 근거로 삼아 갱신한다.
        - "> 마지막 전면 작성:" 날짜를 \(today)로 바꾼다.

        \(commonRules)

        ────────── 기존 인물지 ──────────
        \(existing)

        ────────── 전체 대화 발췌 ──────────
        \(all)
        """
    }

    /// 인물지를 (처음) 짓거나 갱신한다. 블로킹 — 백그라운드에서 부른다.
    static func build(model: ClaudeModel) throws {
        let today = LetterStore.dateString()
        let all = ConversationExtractor.allMarkdown()
        let existing = try? String(contentsOf: Paths.profile, encoding: .utf8)
        let prompt = existing.map { updatePrompt(existing: $0, all: all, today: today) }
            ?? initialPrompt(all: all, today: today)

        LetterStore.log("[profile] \(existing == nil ? "최초 작성" : "갱신") 시작 (모델: \(model.rawValue))")
        let result = try ClaudeCLI.run(prompt: prompt, model: model)
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 300, trimmed.contains("인물지") else {
            throw ClaudeCLI.CLIError(message: "인물지 결과가 비정상이라 반영하지 않았습니다.")
        }
        if let old = existing {
            try? old.write(to: Paths.profileHistory.appendingPathComponent("\(today).md"), atomically: true, encoding: .utf8)
        }
        try trimmed.write(to: Paths.profile, atomically: true, encoding: .utf8)
        AppSettings.profileUpdatedAt = today
        LetterStore.log("[profile] 완료 (\(trimmed.count)자)")
    }

    static var exists: Bool { FileManager.default.fileExists(atPath: Paths.profile.path) }

    /// 마지막 갱신 후 7일이 지났으면 true
    static var isStale: Bool {
        guard exists else { return true }
        guard let last = LetterStore.dateFormatter.date(from: AppSettings.profileUpdatedAt) else { return true }
        return Date().timeIntervalSince(last) > 7 * 86400
    }
}
