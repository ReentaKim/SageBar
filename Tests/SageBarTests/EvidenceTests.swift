import Foundation
import Testing
@testable import SageBar

@Suite("근거 표식")
struct EvidenceTests {
    typealias Evidence = ConversationExtractor.Evidence

    @Test("표식을 처음 나온 순서대로, 중복 없이 모은다")
    func collectsRefs() {
        let t = "첫째다 [[u7]]. 둘째다[[u3, u7]]. 셋째다 [[ u12·u3 ]]."
        #expect(LetterParser.refIDs(in: t) == ["u7", "u3", "u12"])
    }

    @Test("글자 수에 표식을 세지 않는다")
    func charCountIgnoresRefs() {
        #expect(LetterParser.charCount("가나다 [[u17]]. 라마[[u3,u4]]") == LetterParser.charCount("가나다. 라마"))
    }

    @Test("본문 표식을 위첨자로, 없는 번호는 버린다")
    func rendersSuperscripts() {
        let html = LetterParser.paragraphsToHTML("다시 물으셨소 [[u5]]. 지어낸 번호 [[u99]]. 둘 [[u5, u8]].",
                                                 refs: ["u5": 1, "u8": 2])
        #expect(html.contains(##"물으셨소<sup class="sage-ref"><a href="#ev-1">1</a></sup>."##))
        #expect(html.contains("지어낸 번호."))
        #expect(!html.contains("u99"))
        #expect(html.contains(##"<a href="#ev-1">1</a>,<a href="#ev-2">2</a>"##))
    }

    @Test("소제목·부제·실천 항목에서는 표식을 뗀다")
    func stripsFromTitles() throws {
        let raw = """
        SUBTITLE: 하나를 끝내소서 [[u1]]
        ---UPPER---
        ### 소제목 [[u2]]
        상편 [[u2]]
        ---LOWER---
        하편 [[u3]]
        ---CLOSING---
        맺음
        ---ACTIONS---
        - 폴더 정리 [[u4]]
        """
        let l = try LetterParser.parse(raw)
        #expect(l.subtitle == "하나를 끝내소서")
        #expect(l.actions == ["폴더 정리"])
        #expect(l.citedRefs == ["u2", "u3"])
        #expect(!LetterParser.paragraphsToHTML(l.upper).contains("[[u2]]"))
    }

    @Test("근거는 발췌에 있는 번호의 원문만, 편지에 나온 순서로")
    func citedEvidenceUsesExtractorText() throws {
        let raw = "---UPPER---\n상 [[u2]] [[u9]]\n---LOWER---\n하 [[u1]]\n---CLOSING---\n끝"
        let l = try LetterParser.parse(raw)
        let pool = [Evidence(id: "u1", date: "2026-09-28", project: "~/a", text: "원문 하나"),
                    Evidence(id: "u2", date: "2026-09-29", project: "~/b", text: "원문 둘")]
        #expect(LetterGenerator.citedEvidence(l, from: pool).map(\.text) == ["원문 둘", "원문 하나"])
    }

    @Test("발화에 시간순 번호를 붙인다")
    func numbersUtterances() {
        let rows = [ConversationExtractor.Utterance(timestamp: "2026-09-28T01:00:00Z", project: "~/a", folder: "f", text: "가"),
                    ConversationExtractor.Utterance(timestamp: "", project: "~/b", folder: "f", text: "나")]
        let e = ConversationExtractor.numbered(rows)
        #expect(e.map(\.id) == ["u1", "u2"])
        #expect(e[0].date == "2026-09-28")
        #expect(e[1].date == "????-??-??")
    }

    @Test("근거 목록 HTML은 원문을 이스케이프하고, 없으면 비운다")
    func evidenceHTML() {
        #expect(HTMLRenderer.evidenceHTML([]).isEmpty)
        let h = HTMLRenderer.evidenceHTML([Evidence(id: "u4", date: "2026-09-29", project: "~/x", text: "<b>굵게</b>")])
        #expect(h.contains(#"<li id="ev-1">"#))
        #expect(h.contains("&lt;b&gt;"))
    }
}

@Suite("붙여 넣은 글")
struct PasteTagTests {
    @Test("pasted_content 태그만 떼고 내용은 남긴다")
    func stripsTags() {
        let t = "깃허브의\n<pasted_content id=\"a561\">\nhttps://example.com\n</pasted_content id=\"a561\">\n설명해줘"
        let s = ConversationExtractor.stripPasteTags(t)
        #expect(!s.contains("pasted_content"))
        #expect(s.contains("https://example.com"))
    }
}
