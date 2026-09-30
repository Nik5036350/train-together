// swift-tools-version: 6.2
import PackageDescription

// Core logic for the Train Together iOS app, testable on the Mac with
// `swift test`.
//
// - TrainTogetherCore: plain Codable records, enums and formatting. No
//   dependencies, so the widget extension can link it without pulling in GRDB.
// - TrainTogetherKit: the GRDB-backed database, the workout engine (the rules
//   the Rust server used to own) and the sync client.
let package = Package(
    name: "TrainTogetherKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "TrainTogetherCore", targets: ["TrainTogetherCore"]),
        .library(name: "TrainTogetherKit", targets: ["TrainTogetherKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMinor(from: "7.11.1")),
    ],
    targets: [
        .target(name: "TrainTogetherCore"),
        .target(
            name: "TrainTogetherKit",
            dependencies: [
                "TrainTogetherCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "TrainTogetherKitTests",
            dependencies: ["TrainTogetherKit", "TrainTogetherCore"]
        ),
    ]
)
