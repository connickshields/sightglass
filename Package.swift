// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sightglass",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Sightglass", targets: ["Sightglass"]),
    ],
    targets: [
        .target(name: "SightglassCore"),
        .executableTarget(name: "Sightglass", dependencies: ["SightglassCore"]),
        .testTarget(name: "SightglassCoreTests", dependencies: ["SightglassCore"]),
    ]
)
