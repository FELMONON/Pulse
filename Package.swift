// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacMonitorWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MacMonitorWidget", targets: ["MacMonitorWidget"])
    ],
    targets: [
        .target(name: "MacMonitorWidget", path: "Sources")
    ]
)
