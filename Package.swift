// swift-tools-version:5.9
// Núcleo do TraduzaJa (testável com `swift test`). O app é gerado pelo project.yml.
import PackageDescription

let package = Package(
    name: "TraduzaJa",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TraduzaCore", targets: ["TraduzaCore"])],
    targets: [
        .target(name: "TraduzaCore"),
        .testTarget(name: "TraduzaCoreTests", dependencies: ["TraduzaCore"]),
    ]
)
