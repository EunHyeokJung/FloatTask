// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FloatTask",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FloatTask", targets: ["FloatTask"]),
        .executable(name: "floattaskctl", targets: ["FloatTaskCLI"]),
        .library(name: "FloatTaskCore", targets: ["FloatTaskCore"])
    ],
    targets: [
        .target(name: "FloatTaskCore"),
        .executableTarget(name: "FloatTask", dependencies: ["FloatTaskCore"]),
        .executableTarget(name: "FloatTaskCLI", dependencies: ["FloatTaskCore"]),
        .testTarget(name: "FloatTaskCoreTests", dependencies: ["FloatTaskCore"]),
        .testTarget(name: "FloatTaskUITests", dependencies: ["FloatTask"])
    ]
)
