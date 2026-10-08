// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TabbyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TabbyKit", targets: ["TabbyKit"]),
        .executable(name: "Tabby", targets: ["TabbyApp"]),
        .executable(name: "tabby-probe", targets: ["TabbyProbe"]),
    ],
    targets: [
        .target(name: "TabbyKit"),
        .executableTarget(name: "TabbyApp", dependencies: ["TabbyKit"]),
        .executableTarget(name: "TabbyProbe", dependencies: ["TabbyKit"]),
        .testTarget(name: "TabbyKitTests", dependencies: ["TabbyKit"]),
    ]
)
