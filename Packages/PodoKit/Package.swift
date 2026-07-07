// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PodoKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PodoKit", targets: ["PodoKit"]),
    ],
    targets: [
        .target(name: "PodoKit"),
        .testTarget(name: "PodoKitTests", dependencies: ["PodoKit"]),
    ]
)
