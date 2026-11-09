// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TiempoDock",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TiempoDock",
            path: "Sources/TiempoDock"
        )
    ]
)
