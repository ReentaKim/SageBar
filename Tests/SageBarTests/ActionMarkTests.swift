import Foundation
import Testing
@testable import SageBar

@Suite("실천 표시·이력")
struct ActionMarkTests {
    @Test("옛 이력(done 없음)도 읽힌다")
    func decodesLegacyEntry() throws {
        let json = #"{"date":"2026-09-20","persona":"zhuge","subtitle":"s","actions":["a","b","c"]}"#
        let e = try JSONDecoder().decode(HistoryEntry.self, from: Data(json.utf8))
        #expect(e.done == nil)
        #expect(e.actions?.count == 3)
    }

    @Test("점검 프롬프트에 본인 표시가 항목마다 붙는다")
    func previousSectionShowsMarks() {
        var e = HistoryEntry(date: "2026-09-20", persona: "zhuge", subtitle: "s", actions: ["가", "나", "다"])
        e.done = [true, false]
        let s = PromptBuilder.previousSection(e)
        #expect(s.contains("- 가  〔본인 표시: 했음〕"))
        #expect(s.contains("- 나  〔본인 표시: 표시 없음〕"))
        #expect(s.contains("- 다  〔본인 표시: 표시 없음〕"))   // 표시 배열이 짧아도 안전
    }

    @Test("한 번도 표시하지 않았으면 전부 표시 없음")
    func previousSectionWithoutMarks() {
        let e = HistoryEntry(date: "2026-09-20", persona: "zhuge", subtitle: "s", actions: ["가"])
        #expect(PromptBuilder.previousSection(e).contains("〔본인 표시: 표시 없음〕"))
    }
}

@Suite("편지 해석")
struct LetterParserTests {
    @Test("구획과 실천 세 가지를 읽는다")
    func parsesSections() throws {
        let raw = """
        SUBTITLE: 오늘의 한 문장
        ---UPPER---
        상편 본문
        ---LOWER---
        하편 본문
        ---CLOSING---
        맺음
        QUOTE_KOREAN: 구절
        QUOTE_SOURCE: 출처
        ---ACTIONS---
        - 하나
        - 둘
        - 셋
        - 넷
        """
        let l = try LetterParser.parse(raw)
        #expect(l.subtitle == "오늘의 한 문장")
        #expect(l.actions == ["하나", "둘", "셋"])
    }

    @Test("글자 수는 공백을 세지 않는다")
    func charCountSkipsWhitespace() {
        #expect(LetterParser.charCount("가 나\n다") == 3)
    }
}

@Suite("대화 기록 읽기")
struct ExtractorTests {
    @Test("홈 경로의 점·밑줄도 떼어 낸다")
    func cleansProjectName() {
        let home = "/Users/maba.reenta"
        #expect(ConversationExtractor.cleanProjectName("-Users-maba-reenta-hyunyoung", home: home) == "hyunyoung")
        #expect(ConversationExtractor.cleanProjectName("-Users-maba-reenta--MABA-DEV-homepage", home: home) == "MABA-DEV-homepage")
        #expect(ConversationExtractor.cleanProjectName("-Users-maba-reenta", home: home) == "~")
        #expect(ConversationExtractor.cleanProjectName("-private-tmp", home: home) == "-private-tmp")
    }
}
