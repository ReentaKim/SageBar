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

    func showIndex() {
        let engine = SageEngine.shared
        LetterStore.renderArchive(seat: engine.todayPersona ?? engine.nextPersona(), generating: engine.isGenerating)
        show()
        window?.title = "SageBar — 현자의 서재"
        webView.loadFileURL(Paths.indexPage, allowingReadAccessTo: Paths.appSupport)
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
