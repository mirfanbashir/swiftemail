// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftEmail",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftEmail",
            targets: ["SwiftEmail"]),
    ],
    targets: [
        .target(
            name: "SwiftEmail"),
        .testTarget(
            name: "SwiftEmailTests",
            dependencies: ["SwiftEmail"]
        ),
    ]
)
