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
        )
    ],
    swiftLanguageVersions: [.v5]
)
