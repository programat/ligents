// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Ligents",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Ligents", targets: ["Ligents"])
    ],
    targets: [
        .executableTarget(
            name: "Ligents",
            path: "Sources/Ligents",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
