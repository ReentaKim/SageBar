import Foundation

/// 편지 아래 답장 칸의 대화. 턴마다 claude -p 를 새로 부르고(세션 없음), 편지 원문과 대화 기록을 함께 넘긴다.
/// 블로킹 호출이므로 백그라운드에서 부른다.
enum ChatEngine {
    static let model: ClaudeModel = .sonnet      // 대화는 빠르게 — 아침 편지만 설정의 모델을 쓴다
    static let timeout: TimeInterval = 180
    static let maxMessageChars = 2000

    struct ChatError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// 독자의 말을 기록하고 현자의 답을 받아 기록한 뒤 돌려준다.
    static func reply(date: String, text: String) throws -> String {
        let message = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxMessageChars))
        guard !message.isEmpty else { throw ChatError(message: "보낼 말이 비어 있습니다.") }
        guard let pid = LetterStore.personaForDate(date) else {
            throw ChatError(message: "\(date)의 편지 기록이 없어 답장을 보낼 수 없습니다.")
        }
        let persona = pid.persona
        let transcript = LetterStore.chatTranscript(for: date)   // 방금 말은 따로 넘기므로 기록 전에 읽는다
        let now = ISO8601DateFormatter().string(from: Date())
        LetterStore.appendChat(date: date, ChatMessage(role: "me", persona: pid.rawValue, text: message, at: now))
        LetterStore.log("[chat \(pid.rawValue)] \(date) 답장 받음 (\(message.count)자)")

        let prompt = PromptBuilder.chatPrompt(
            persona: persona,
            profile: (try? String(contentsOf: Paths.profile, encoding: .utf8)) ?? "(인물지 없음)",
            letter: (try? String(contentsOf: LetterStore.rawURL(for: date), encoding: .utf8)) ?? "",
            transcript: transcript, message: message, date: date)
        let raw = try ClaudeCLI.run(prompt: prompt, model: model, timeout: timeout)
        let answer = clean(raw)
        guard !answer.isEmpty else { throw ChatError(message: "\(persona.displayName)의 답이 비어 있습니다.") }

        LetterStore.appendChat(date: date, ChatMessage(role: "sage", persona: pid.rawValue, text: answer,
                                                        at: ISO8601DateFormatter().string(from: Date())))
        let hanja = LetterParser.hanjaCount(answer)
        LetterStore.log("[chat \(pid.rawValue)] 답 \(answer.count)자\(hanja > 0 ? ", 경고: 한자 \(hanja)자" : "")")
        return answer
    }

    /// 모델이 가끔 붙이는 이름표("제갈량:")·감싼 따옴표를 걷어 낸다
    static func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for p in Persona.all {
            for sep in [":", "："] where s.hasPrefix(p.displayName + sep) {
                s = String(s.dropFirst(p.displayName.count + 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        if s.count > 2, let f = s.first, let l = s.last, (f == "\"" && l == "\"") || (f == "“" && l == "”") {
            s = String(s.dropFirst().dropLast())
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
