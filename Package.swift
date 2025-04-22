
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExtWSClient",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "ExtWSClient", targets: ["ExtWSClient"]),
    ],
    targets: [
        .target(name: "ExtWSClient", dependencies: []),
        .testTarget(name: "ExtWSClientTests", dependencies: ["ExtWSClient"]),
    ]
)
