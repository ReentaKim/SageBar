// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SageBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SageBar",
            path: "Sources/SageBar",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        ),
        // 실행 대상을 @testable import 로 시험한다 (순수 함수 위주: 해석·집계·걸러내기)
        .testTarget(
            name: "SageBarTests",
            dependencies: ["SageBar"],
            path: "Tests/SageBarTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
