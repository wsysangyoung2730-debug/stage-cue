// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StageCueCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "StageCueCore", targets: ["StageCueCore"])],
    targets: [
        .target(name: "StageCueCore"),
        .testTarget(name: "StageCueCoreTests", dependencies: ["StageCueCore"])
    ]
)
