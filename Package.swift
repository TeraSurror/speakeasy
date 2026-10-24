// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Speakeasy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Speakeasy", targets: ["Speakeasy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "SpeakeasyKit",
            dependencies: [.product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")],
            path: "Sources/SpeakeasyKit"
        ),
        .executableTarget(
            name: "Speakeasy",
            dependencies: ["SpeakeasyKit"],
            path: "Sources/Speakeasy"
        ),
        .testTarget(
            name: "SpeakeasyTests",
            dependencies: ["SpeakeasyKit"],
            path: "Tests/SpeakeasyTests"
        ),
    ]
)
