// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceType",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceType",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/VoiceType"
        )
    ]
)
