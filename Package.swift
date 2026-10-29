// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TakeAWalk",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TakeAWalk", targets: ["TakeAWalk"])],
    targets: [
        .target(name: "WalkCore"),
        .target(name: "ReminderAudio"),
        .executableTarget(name: "TakeAWalk", dependencies: ["WalkCore", "ReminderAudio"]),
        .executableTarget(name: "WalkCoreChecks", dependencies: ["WalkCore", "ReminderAudio"], path: "Tests/WalkCoreTests")
    ]
)
