// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MasterDance",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "MasterDanceCore", targets: ["MasterDanceCore"]),
        .executable(name: "MasterDanceAdmin", targets: ["MasterDanceAdmin"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/supabase/supabase-swift.git",
            exact: "2.46.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            revision: "swift-6.3.2-RELEASE"
        )
    ],
    targets: [
        .target(
            name: "MasterDanceCore",
            path: "packages/MasterDanceCore/Sources/MasterDanceCore"
        ),
        .testTarget(
            name: "MasterDanceCoreTests",
            dependencies: [
                "MasterDanceCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "packages/MasterDanceCore/Tests/MasterDanceCoreTests"
        ),
        .executableTarget(
            name: "MasterDanceAdmin",
            dependencies: [
                "MasterDanceCore",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "apps",
            exclude: [
                "MasterDanceMobile",
                "MasterDanceAdmin/Info.plist",
                "project.yml",
                "Shared/Resources"
            ],
            sources: [
                "MasterDanceAdmin",
                "Shared"
            ]
        )
    ]
)
