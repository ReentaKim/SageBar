import AppKit

/// 새 버전 알림 — GitHub 최신 릴리스의 태그를 하루 한 번 확인해 메뉴와 메뉴바 아이콘에 표시한다.
/// 보내는 것은 User-Agent("SageBar/<버전>")뿐이다. 설치·교체는 하지 않는다(brew 상태와 어긋나지 않게).
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    nonisolated static let apiURL = URL(string: "https://api.github.com/repos/ReentaKim/SageBar/releases/latest")!
    nonisolated static let releasesURL = URL(string: "https://github.com/ReentaKim/SageBar/releases/latest")!
    static let brewCommand = "brew upgrade --cask sagebar"

    private enum Key {
        static let latest = "update.latestVersion"
        static let url = "update.releaseURL"
    }
    private var timer: Timer?

    struct UpdateError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    nonisolated static var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    /// 확인해 둔 최신 버전이 지금 버전보다 새로우면 그 버전 (없으면 nil)
    var availableVersion: String? {
        guard AppSettings.checkUpdates, let latest = UserDefaults.standard.string(forKey: Key.latest),
              Self.isNewer(latest, than: Self.currentVersion) else { return nil }
        return latest
    }
    var releaseURL: URL {
        UserDefaults.standard.string(forKey: Key.url).flatMap(URL.init(string:)) ?? Self.releasesURL
    }

    static var installedWithBrew: Bool {
        ["/opt/homebrew/Caskroom/sagebar", "/usr/local/Caskroom/sagebar"].contains { FileManager.default.fileExists(atPath: $0) }
    }

    func start() {
        guard timer == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in self?.check() }
        let t = Timer(timeInterval: 24 * 60 * 60, repeats: true) { _ in Task { @MainActor in UpdateChecker.shared.check() } }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check() {
        guard AppSettings.checkUpdates else { return }
        Task {
            do {
                let (tag, url) = try await Self.fetchLatest()
                let latest = Self.normalize(tag)
                UserDefaults.standard.set(latest, forKey: Key.latest)
                UserDefaults.standard.set(url, forKey: Key.url)
                let newer = Self.isNewer(latest, than: Self.currentVersion)
                LetterStore.log("[update] 최신 \(latest), 현재 \(Self.currentVersion)\(newer ? " — 새 버전 있음" : "")")
                StatusBarController.shared.refreshIcon()
            } catch {
                LetterStore.log("[update] 확인 실패: \(error.localizedDescription)")
            }
        }
    }

    nonisolated static func fetchLatest() async throws -> (tag: String, url: String) {
        var req = URLRequest(url: apiURL, timeoutInterval: 20)
        req.setValue("SageBar/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else {
            throw UpdateError(message: "GitHub 응답을 읽지 못했습니다 (\((resp as? HTTPURLResponse)?.statusCode ?? 0))")
        }
        return (tag, obj["html_url"] as? String ?? releasesURL.absoluteString)
    }

    nonisolated static func normalize(_ tag: String) -> String { tag.hasPrefix("v") ? String(tag.dropFirst()) : tag }

    /// "0.10.0" > "0.9.3" 처럼 숫자 단위로 비교
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }, pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// 메뉴 항목을 눌렀을 때: brew 설치면 명령을 복사해 두고, 릴리스 페이지를 연다
    func showUpdateHelp() {
        guard let version = availableVersion else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "SageBar \(version)이 나왔습니다"
        if Self.installedWithBrew {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.brewCommand, forType: .string)
            alert.informativeText = "터미널에 아래 명령을 붙여 넣으면 올라갑니다 (이미 복사해 두었습니다).\n\n\(Self.brewCommand)\n\n지금 버전: \(Self.currentVersion)"
        } else {
            alert.informativeText = "릴리스 페이지에서 새 dmg를 받아 응용 프로그램 폴더의 SageBar를 바꾸세요.\n\n지금 버전: \(Self.currentVersion)"
        }
        alert.addButton(withTitle: "바뀐 점 보기")
        alert.addButton(withTitle: "닫기")
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(releaseURL) }
    }
}
