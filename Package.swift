// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sightglass",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "SightglassCore"),
        .testTarget(name: "SightglassCoreTests", dependencies: ["SightglassCore"]),
    ]
)
