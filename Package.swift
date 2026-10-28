// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TakeAWalk",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TakeAWalk", targets: ["TakeAWalk"])],
    targets: [
        .target(name: "WalkCore"),
        .executableTarget(name: "TakeAWalk", dependencies: ["WalkCore"]),
        .executableTarget(name: "WalkCoreChecks", dependencies: ["WalkCore"], path: "Tests/WalkCoreTests")
    ]
)
