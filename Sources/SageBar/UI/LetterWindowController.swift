import AppKit
import WebKit

/// 편지를 보여주는 창. WKWebView 하나로 대기 화면 → 완성본으로 자리에서 바꾼다.
@MainActor
final class LetterWindowController: NSWindowController, WKNavigationDelegate {
    static let shared = LetterWindowController()

    private let webView: WKWebView

    private init() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let bridge = ScriptBridge()
        config.userContentController.add(bridge, name: "sage")   // 편지 JS → 앱 (답장 칸)
        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 1120),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "SageBar"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 600)
        window.setFrameAutosaveName("SageBar.LetterWindow")
        window.contentView = webView
        super.init(window: window)
        bridge.owner = self
        webView.navigationDelegate = self
        // 편지 안 스크립트가 "앱 안에서 열렸다"를 알 수 있게 (인쇄 버튼이 sagebar://print 로 보내도록)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) SageBar"
        if !window.setFrameUsingName("SageBar.LetterWindow") {
            centerOnScreen(window)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func centerOnScreen(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let h = min(1120, vf.height - 40)
        let w: CGFloat = 980
        window.setFrame(NSRect(x: vf.midX - w / 2, y: vf.maxY - h - 20, width: w, height: h), display: false)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    func load(_ url: URL) {
        window?.title = "SageBar — \(url.deletingPathExtension().lastPathComponent)"
        webView.loadFileURL(url, allowingReadAccessTo: Paths.appSupport)
    }

    func showWaiting(persona: Persona, hint: String) {
        if let url = HTMLRenderer.writeStatusPage(persona: persona, title: persona.waitingTitle,
                                                  line: persona.waitingLine, hint: hint, animated: true) {
            window?.title = "SageBar — \(persona.displayName)"
            webView.loadFileURL(url, allowingReadAccessTo: Paths.appSupport)
        }
    }

    func showFailure(persona: Persona, message: String) {
        let extra = "<div class=\"err\">\(HTMLEscape.escape(message))</div>"
        if let url = HTMLRenderer.writeStatusPage(persona: persona, title: persona.failTitle, line: persona.failLine,
                                                  hint: "메뉴바 아이콘 → \"지금 새로 짓기\"로 다시 시도할 수 있습니다.",
                                                  animated: false, extra: extra) {
            webView.loadFileURL(url, allowingReadAccessTo: Paths.appSupport)
        }
    }

    /// 보관(인쇄·PDF): WKWebView는 window.print()를 무시하므로 앱이 인쇄 대화상자를 연다.
    /// 대화상자의 PDF 메뉴에서 "PDF로 저장"을 고르면 파일로 보관된다.
    func printCurrent() {
        guard let window else { return }
        let info = NSPrintInfo(dictionary: [:])
        info.orientation = .portrait
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = false
        info.topMargin = 28; info.bottomMargin = 28; info.leftMargin = 28; info.rightMargin = 28
        let op = webView.printOperation(with: info)
        // WebKit 특성: 인쇄 뷰의 크기를 용지 크기로 잡아 주지 않으면 빈 페이지가 나온다
        op.view?.frame = NSRect(origin: .zero, size: info.paperSize)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.jobTitle = window.title
        op.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        LetterStore.log("인쇄 대화상자 열기: \(window.title)")
    }

    /// Claude Code CLI가 없을 때의 안내 화면 — 설치 링크와 절차
    func showMissingCLI(persona: Persona) {
        let extra = """
        <div class="err" style="text-align:left">
        SageBar는 이 Mac에 설치된 <b>Claude Code</b>로 글을 짓습니다. 지금은 <code>claude</code> 명령을 찾을 수 없습니다.<br><br>
        1. <a href="\(ClaudeCLI.installURL.absoluteString)">claude.com/claude-code</a> 에서 Claude Code를 설치합니다.<br>
        2. 터미널을 열어 <code>claude</code> 를 한 번 실행해 로그인합니다.<br>
        3. 메뉴바의 SageBar → "오늘의 조언 보기"를 누르면 이어서 진행됩니다.<br><br>
        이미 설치했다면 설정 › 고급에서 <code>claude</code> 경로를 직접 지정할 수 있습니다.
        </div>
        """
        if let url = HTMLRenderer.writeStatusPage(persona: persona, title: "붓이 없나이다",
                                                  line: "글을 지을 연장(Claude Code)이 이 Mac에 없습니다.",
                                                  hint: "", animated: false, extra: extra) {
            window?.title = "SageBar — Claude Code 설치 필요"
            webView.loadFileURL(url, allowingReadAccessTo: Paths.appSupport)
        }
    }

    func showIndex() {
        let engine = SageEngine.shared
        LetterStore.renderArchive(seat: engine.todayPersona ?? engine.nextPersona(), generating: engine.isGenerating)
        show()
        window?.title = "SageBar — 현자의 서재"
        webView.loadFileURL(Paths.indexPage, allowingReadAccessTo: Paths.appSupport)
    }

    // MARK: 답장 대화 — JS가 보낸 말을 claude 로 넘기고 답을 페이지에 넣는다

    fileprivate func handleScriptMessage(_ body: Any) {
        guard let dict = body as? [String: Any], dict["type"] as? String == "chat",
              let date = dict["date"] as? String, let text = dict["text"] as? String else { return }
        Task {
            do {
                let answer = try await Task.detached(priority: .userInitiated) { try ChatEngine.reply(date: date, text: text) }.value
                callJS("sageChat && sageChat.receive", answer)
            } catch {
                LetterStore.log("[chat] 실패: \(error.localizedDescription)")
                callJS("sageChat && sageChat.fail", "답을 받지 못했습니다 — \(error.localizedDescription)")
            }
        }
    }

    /// 문자열 인자는 JSON 배열로 인코딩해 따옴표·줄바꿈을 안전하게 넘긴다
    private func callJS(_ function: String, _ arg: String) {
        guard let data = try? JSONEncoder().encode([arg]), let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("\(function)(\(json.dropFirst().dropLast()))", completionHandler: nil)
    }

    /// 편지를 열 때마다 저장된 실천 표시를 넣는다 (HTML은 지을 때 고정이라 그 뒤 표시가 반영돼 있지 않다)
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, url.isFileURL else { return }
        let date = url.deletingPathExtension().lastPathComponent
        guard date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return }
        refreshActionMarks(date: date)
    }

    /// 메뉴에서 표시를 바꿨을 때도 부른다
    func refreshActionMarks(date: String) {
        guard webView.url?.deletingPathExtension().lastPathComponent == date else { return }
        let marks = LetterStore.actionMarks(date: date)
        guard let data = try? JSONEncoder().encode(marks), let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.sageActions && sageActions.set(\(json))", completionHandler: nil)
    }

    // 편지 안의 링크(지난 글, 목록)는 창 안에서, 외부 링크는 브라우저로
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, url.scheme == "sagebar" {
            URLRouter.handle(url)          // 피드백 버튼 등 — 창 안에서 바로 처리
            decisionHandler(.cancel)
            return
        }
        if let url = navigationAction.request.url, !url.isFileURL, navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

/// WKUserContentController는 핸들러를 강하게 잡으므로, 창 컨트롤러 대신 약한 참조를 든 중계 객체를 등록한다
@MainActor
private final class ScriptBridge: NSObject, WKScriptMessageHandler {
    weak var owner: LetterWindowController?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.handleScriptMessage(message.body)
    }
}
