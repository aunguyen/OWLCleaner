// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OWLCleaner",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "OWLCleanerKit"
        ),
        .executableTarget(
            name: "OWLCleaner",
            dependencies: ["OWLCleanerKit"]
        ),
        .testTarget(
            name: "OWLCleanerKitTests",
            dependencies: ["OWLCleanerKit"]
        ),
    ]
)
