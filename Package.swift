// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DrillKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "DrillKit", targets: ["DrillKit"])
    ],
    targets: [
        .target(name: "DrillKit"),
        .testTarget(name: "DrillKitTests", dependencies: ["DrillKit"])
    ]
)
