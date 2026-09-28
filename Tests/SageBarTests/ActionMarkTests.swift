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
        let home = "/Users/jane.doe"
        #expect(ConversationExtractor.cleanProjectName("-Users-jane-doe-notes", home: home) == "notes")
        #expect(ConversationExtractor.cleanProjectName("-Users-jane-doe--ACME-DEV-homepage", home: home) == "ACME-DEV-homepage")
        #expect(ConversationExtractor.cleanProjectName("-Users-jane-doe", home: home) == "~")
        #expect(ConversationExtractor.cleanProjectName("-private-tmp", home: home) == "-private-tmp")
    }
}

@Suite("프로젝트 실제 경로")
struct ProjectRootTests {
    @Test("한글 경로도 폴더 이름과 똑같이 바뀐다")
    func mangles() {
        #expect(ConversationExtractor.mangle("/Users/jane.doe/Cowork/고객사업무") == "-Users-jane-doe-Cowork------")
    }

    @Test("하위 폴더가 아니라 뿌리를 고른다")
    func picksRoot() {
        let folder = "-Users-jane-doe-Cowork------"
        let root = ConversationExtractor.pickRoot(folder: folder, candidates: [
            "/Users/jane.doe/Cowork/고객사업무/_현장점검_v0.2",
            "/Users/jane.doe/Cowork/고객사업무",
        ])
        #expect(root == "/Users/jane.doe/Cowork/고객사업무")
        #expect(ConversationExtractor.pickRoot(folder: folder, candidates: [String]()) == nil)
        // 작업 폴더 이름을 나중에 바꿔 맞는 것이 없으면 가장 짧은 경로
        #expect(ConversationExtractor.pickRoot(folder: "-Users-me-CC-3-web-demo-store",
                                               candidates: ["/Users/me/CC/demo-store/src", "/Users/me/CC/demo-store"]) == "/Users/me/CC/demo-store")
    }

    @Test("홈 아래는 ~/ 로, 밖은 그대로")
    func displaysName() {
        let home = "/Users/jane.doe"
        #expect(ConversationExtractor.displayName(root: "/Users/jane.doe/Cowork/고객사업무", home: home) == "~/Cowork/고객사업무")
        #expect(ConversationExtractor.displayName(root: "/Users/jane.doe", home: home) == "~")
        #expect(ConversationExtractor.displayName(root: "/Users/jane.doex/a", home: home) == "/Users/jane.doex/a")
        #expect(ConversationExtractor.displayName(root: "/private/tmp", home: home) == "/private/tmp")
    }
}
