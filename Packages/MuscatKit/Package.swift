// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MuscatKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MuscatKit", targets: ["MuscatKit"]),
    ],
    targets: [
        .target(name: "MuscatKit"),
        .testTarget(name: "MuscatKitTests", dependencies: ["MuscatKit"]),
    ]
)
