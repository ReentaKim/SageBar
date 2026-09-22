import Foundation

/// Claude Code CLI(`claude -p`) 호출. API 키 없이 사용자의 로그인 세션을 그대로 쓴다.
enum ClaudeCLI {
    struct CLIError: LocalizedError {
        let message: String
        var notFound: Bool = false        // claude 실행 파일 자체가 없음 (설치 안내 대상)
        var errorDescription: String? { message }
    }
    static let installURL = URL(string: "https://claude.com/claude-code")!

    static let extraPathDirs: [String] = [
        "\(NSHomeDirectory())/.local/bin",
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "\(NSHomeDirectory())/.npm-global/bin",
        "\(NSHomeDirectory())/.volta/bin",
        "/usr/bin", "/bin", "/usr/sbin", "/sbin",
    ]

    /// 설정에 적힌 경로 → 흔한 설치 위치 → 로그인 셸의 `command -v claude` 순으로 찾는다.
    static func locate() -> URL? {
        let fm = FileManager.default
        let override = AppSettings.claudePath.trimmingCharacters(in: .whitespaces)
        if !override.isEmpty, fm.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        for dir in extraPathDirs {
            let p = "\(dir)/claude"
            if fm.isExecutableFile(atPath: p) { return URL(fileURLWithPath: p) }
        }
        if let found = shellWhich("claude"), fm.isExecutableFile(atPath: found) {
            return URL(fileURLWithPath: found)
        }
        return nil
    }

    private static func shellWhich(_ name: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-l", "-c", "command -v \(name)"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    static func version(at url: URL) -> String? {
        let p = Process()
        p.executableURL = url
        p.arguments = ["--version"]
        p.environment = environment()
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let current = env["PATH"] ?? ""
        env["PATH"] = (extraPathDirs + [current]).joined(separator: ":")
        env["HOME"] = env["HOME"] ?? NSHomeDirectory()
        env["LANG"] = env["LANG"] ?? "ko_KR.UTF-8"
        return env
    }

    /// 프롬프트를 표준입력으로 넘겨 답변 전문을 돌려받는다. 블로킹 호출이므로 백그라운드에서 부른다.
    static func run(prompt: String, model: ClaudeModel, timeout: TimeInterval = 1800) throws -> String {
        guard let exe = locate() else {
            throw CLIError(message: "Claude Code CLI(claude)를 찾을 수 없습니다. 설치 후 터미널에서 한 번 로그인하거나, 설정 › 고급에서 경로를 지정하세요.", notFound: true)
        }
        let p = Process()
        p.executableURL = exe
        p.arguments = ["-p", "--model", model.rawValue, "--output-format", "text"]
        p.environment = environment()
        p.currentDirectoryURL = Paths.logs   // 프로젝트의 CLAUDE.md 등이 끼어들지 않는 빈 폴더

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        p.standardInput = stdin
        p.standardOutput = stdout
        p.standardError = stderr

        try p.run()

        // 프롬프트가 파이프 버퍼(64KB)보다 클 수 있으므로 별도 스레드에서 쓴다
        let promptData = Data(prompt.utf8)
        DispatchQueue.global(qos: .userInitiated).async {
            stdin.fileHandleForWriting.write(promptData)
            try? stdin.fileHandleForWriting.close()
        }

        var errData = Data()
        let errQueue = DispatchQueue(label: "sagebar.stderr")
        errQueue.async { errData = stderr.fileHandleForReading.readDataToEndOfFile() }

        let deadline = DispatchTime.now() + timeout
        let doneGroup = DispatchGroup()
        doneGroup.enter()
        var outData = Data()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = stdout.fileHandleForReading.readDataToEndOfFile()
            doneGroup.leave()
        }
        if doneGroup.wait(timeout: deadline) == .timedOut {
            p.terminate()
            throw CLIError(message: "claude 응답이 \(Int(timeout / 60))분을 넘겨 중단했습니다.")
        }
        p.waitUntilExit()
        errQueue.sync {}

        let out = String(decoding: outData, as: UTF8.self)
        if p.terminationStatus != 0 {
            let err = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw CLIError(message: "claude가 오류로 끝났습니다 (코드 \(p.terminationStatus)). \(err.isEmpty ? out.prefix(400) : err.prefix(400))")
        }
        if out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CLIError(message: "claude가 빈 답을 돌려주었습니다.")
        }
        return out
    }
}
