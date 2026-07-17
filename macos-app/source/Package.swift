// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MasterDanceReserveMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MasterDanceReserve", targets: ["MasterDanceReserve"])
    ],
    targets: [
        .executableTarget(
            name: "MasterDanceReserve",
            path: "Sources/MasterDanceReserve"
        )
    ]
)
