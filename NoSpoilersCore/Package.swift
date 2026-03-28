// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoSpoilersCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "NoSpoilersCore", targets: ["NoSpoilersCore"]),
    ],
    targets: [
        .target(name: "NoSpoilersCore"),
        .testTarget(name: "NoSpoilersCoreTests", dependencies: ["NoSpoilersCore"]),
    ]
)
