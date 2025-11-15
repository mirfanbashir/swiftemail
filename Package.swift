// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftEmail",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftEmail",
            targets: ["Core", "Providers", "Testing"]
        ),
    ],
    targets: [
        // Core module with fundamental types and protocols
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        
        // Providers module with email service implementations
        .target(
            name: "Providers",
            dependencies: ["Core"],
            path: "Sources/Providers"
        ),
        
        // Testing utilities
        .target(
            name: "Testing",
            dependencies: ["Core"],
            path: "Sources/Testing"
        ),
        
        // Tests
        .testTarget(
            name: "SwiftEmailTests",
            dependencies: ["Core", "Providers", "Testing"],
            path: "Tests/SwiftEmailTests"
        ),
    ]
)
