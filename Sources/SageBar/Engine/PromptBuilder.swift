import Foundation

/// 인물별 조언 프롬프트 조립. 공통부(사실 근거·한자 금지·출력 형식)는 여기서, 어조는 Persona.voiceGuide에서.
enum PromptBuilder {
    static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]

    static func weekdayKorean(_ date: Date) -> String {
        weekdayNames[Calendar.current.component(.weekday, from: date) - 1] + "요일"
    }

    /// 지난 글의 권고를 프롬프트용 문단으로
    static func previousSection(_ prev: HistoryEntry?) -> String {
        guard let prev else { return "(없음 — 첫 글이므로 ---FOLLOWUP--- 구획은 쓰지 않는다)" }
        let who = PersonaID(rawValue: prev.persona)?.persona.displayName ?? prev.persona
        var s = "날짜: \(prev.date) / 지은 인물: \(who) / 부제: \(prev.subtitle)\n권한 것:\n"
        if let acts = prev.actions, !acts.isEmpty {
            s += acts.map { "- \($0)" }.joined(separator: "\n")
        } else {
            s += "(항목 기록이 없음 — 부제를 근거로 짧게만 점검한다)"
        }
        return s
    }

    static func letterPrompt(persona: Persona, profile: String, recent: String, recentTopics: String,
                             date: Date, length: LetterLength, recentDays: Int,
                             previous: HistoryEntry? = nil, feedback: String = "") -> String {
        let today = LetterStore.dateString(date)
        let upperTarget = length.minUpper + 200
        let lowerTarget = length.minLower + 200
        let total = length.minUpper + length.minLower
        let followupFormat = previous == nil ? "" : """
        ---FOLLOWUP---
        (지난 조언 점검 — 위 "지난 글의 권고"에 적힌 항목 하나하나를 최근 발화 발췌와 대조해
         "했다 / 안 했다 / 기록으로는 알 수 없다" 가운데 하나로 정직하게 판정하고 근거 발화를 인용한다.
         지어내지 마라. 300~600자. 지난 글이 다른 인물의 것이면 "지난번 \(PersonaID(rawValue: previous!.persona)?.persona.displayName ?? "")이(가) …"처럼
         그 인물을 밝힌다. 인물 어조를 유지하되, 잘한 것은 짧게 인정하고 안 한 것은 이유를 묻는다.
         구획 첫 줄에 종합 판정을 "FOLLOWUP_MOOD: pleased" (대체로 했다) / "FOLLOWUP_MOOD: stern" (대체로 안 했다) /
         "FOLLOWUP_MOOD: neutral" (알 수 없다·반반) 가운데 하나로 적고, 그 다음 줄부터 본문을 쓴다.)

        """
        return """
        \(persona.voiceGuide)

        상대는 AI 코딩 도구(Claude Code)를 쓰며 일하는 사람이다. 아래는 상대의 인물지와 최근 행적이니,
        오직 이 사실에 근거해서만 글을 쓴다. 없는 사실을 지어내지 말 것. 추측이 필요하면
        "헤아리건대"류의 표현으로 추측임을 드러낼 것. 인물지에 이름이 있으면 그 이름과 직함으로
        불러도 좋고, 없으면 "\(persona.addressee)"라고만 부른다.

        ────────── 인물지 (상대에 대해 이미 파악된 것) ──────────
        \(profile)

        ────────── 최근 \(recentDays)일 상대의 발화 발췌 ──────────
        \(recent)

        ────────── 이미 다룬 주제 (최근 글들, 되풀이하지 말 것) ──────────
        \(recentTopics.isEmpty ? "(아직 없음 — 첫 글)" : recentTopics)

        ────────── 지난 글의 권고 (오늘 점검할 것) ──────────
        \(previousSection(previous))

        ────────── 독자의 반응 (편지 아래 버튼으로 남긴 것) ──────────
        \(feedback.isEmpty ? "(아직 없음)" : feedback)
        - "뻔했다"가 많으면: 일반론을 줄이고 상대의 실제 발화 인용을 늘리며, 지난 글들과 다른 각도를 잡는다.
        - "찔렸다"가 많으면: 그 직설의 수위와 구체성을 유지한다.

        ────────── 오늘 ──────────
        날짜: \(today) (\(weekdayKorean(date)))

        ────────── 아주 중요한 규칙 — 한자를 절대 쓰지 말 것 ──────────
        상대는 한자를 읽지 못한다. **한자 글자는 단 한 글자도 쓰지 마라.** 한 글자짜리 한자도 안 된다.
        한자어라도 한글로 표기한 것("상소문", "승상", "윤음")은 정상적인 한국어이므로 그대로 쓴다.
        소제목도 한자 없이 완전한 한글 문장으로 짓는다. 로마자·그리스 문자도 인용 출처의 고유명사가
        아니면 쓰지 않는다.

        ────────── 공통 어조 지침 ──────────
        - 두루뭉술한 일반론 대신, 상대의 실제 발화·행동을 구체적으로 인용하며 짚는다.
        - 인물별 문체를 유지하되, 현대 한국어로 읽기 어렵지 않게 한다.
        - 이미 다룬 주제 목록과 겹치지 않는 새 각도를 잡는다.

        ────────── 출력 형식 (반드시 이 형식을 정확히 지킬 것) ──────────
        SUBTITLE: (오늘 글 전체를 관통하는 한 줄 부제, 15자 내외, 순한글)
        \(followupFormat)---UPPER---
        (\(persona.upperMark) "\(persona.upperTitle)" — AI 코딩 도구(Claude Code)를 어떻게 쓰면 좋을지,
         상대가 아직 서투른 부분을 콕 집어 조언한다. 반드시 \(upperTarget)자 이상.
         ### 로 시작하는 소제목을 3~4개 두고, 소제목은 한자 없이 완전한 한글 문구로 짓는다.
         인물지 5절의 강점·약점과 최근 발화에서 드러난 습관을 근거로 구체적 처방을 낸다.)
        ---LOWER---
        (\(persona.lowerMark) "\(persona.lowerTitle)" — 상대의 일과 삶의 방향에 대한 조언.
         반드시 \(lowerTarget)자 이상. ### 소제목 3~4개, 역시 순한글.
         인물지 2~4절과 6절, 최근 발화에서 드러난 실제 상황에 근거해 방향을 짚는다.)
        ---CLOSING---
        (맺음 문단 2~3개. 인물답게 마무리하되, 끝에서만 짧게 격려한다.)
        QUOTE_KOREAN: (오늘의 한 구절 — \(persona.quoteSourceHint) 가운데 실제로 있는 구절을
         한글 풀이로만 옮긴 한 문장. 원문은 절대 적지 마라.)
        QUOTE_SOURCE: (그 구절의 출처를 한글로만, 예: 논어 / 플라톤 변명 / 즐거운 학문 / 세종실록)
        ---ACTIONS---
        - (오늘 글에서 상대에게 권한 구체적 실천 항목 1 — 한 줄, 순한글, 내일 대화 기록으로 했는지 확인할 수 있는 행동)
        - (항목 2)
        - (항목 3)

        위 형식의 구획 표시(SUBTITLE:, ---UPPER--- 등)를 정확히 그대로 쓰고, 그 외의 안내문·설명은
        절대 덧붙이지 마라. 상편·하편 분량 합이 \(total)자를 넘어야 한다(점검 구획은 분량에 넣지 않는다).
        쓰기를 마쳤으면 본문 전체를 다시 훑어, 한자 글자가 단 하나라도 섞여 있지 않은지 스스로 검토하라.
        """
    }

    static func retryNote(length: LetterLength) -> String {
        """

        ── 추가 지시 ──
        지난 번 답변은 분량이 모자랐다. 첫 부분은 \(length.minUpper + 400)자, 둘째 부분은 \(length.minLower + 400)자를
        반드시 넘기도록 각 소제목마다 구체적 사례·근거를 한 단락씩 더 보태어 다시 지어라.
        구획 표시 형식은 동일하게 지켜라.
        """
    }
}
