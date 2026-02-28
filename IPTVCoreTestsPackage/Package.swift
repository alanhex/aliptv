// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IPTVCoreTestsPackage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IPTVCoreSupport", targets: ["IPTVCoreSupport"])
    ],
    targets: [
        .target(name: "IPTVCoreSupport"),
        .testTarget(name: "IPTVCoreSupportTests", dependencies: ["IPTVCoreSupport"])
    ]
)
