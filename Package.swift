// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wallhaven",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(name: "Wallhaven", targets: ["Wallhaven"]),
    ],
    targets: [
        .target(
            name: "Wallhaven",
            path: "Sources",
            resources: [.process("Resources")]
        ),
    ]
)
