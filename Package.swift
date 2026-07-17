// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MasterDance",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "MasterDanceCore", targets: ["MasterDanceCore"])
    ],
    targets: [
        .target(
            name: "MasterDanceCore",
            path: "packages/MasterDanceCore/Sources/MasterDanceCore"
        ),
        .testTarget(
            name: "MasterDanceCoreTests",
            dependencies: ["MasterDanceCore"],
            path: "packages/MasterDanceCore/Tests/MasterDanceCoreTests"
        )
    ]
)
