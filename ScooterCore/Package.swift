// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScooterCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ScooterCore", targets: ["ScooterCore"]),
    ],
    targets: [
        .target(name: "ScooterCore"),
        .testTarget(name: "ScooterCoreTests", dependencies: ["ScooterCore"]),
    ]
)
