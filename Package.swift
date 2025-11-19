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
            targets: ["SwiftEmailCore", "SwiftEmailProviders", "SwiftEmailMocks"]
        ),
    ],
    targets: [
        // Core module with fundamental types and protocols
        .target(
            name: "SwiftEmailCore",
            path: "Sources/SwiftEmailCore"
        ),
        
        // Providers module with email service implementations
        .target(
            name: "SwiftEmailProviders",
            dependencies: ["SwiftEmailCore"],
            path: "Sources/SwiftEmailProviders"
        ),
        
        // Testing utilities
        .target(
            name: "SwiftEmailMocks",
            dependencies: ["SwiftEmailCore"],
            path: "Sources/SwiftEmailMocks"
        ),
        
        // Tests
        .testTarget(
            name: "SwiftEmailTests",
            dependencies: ["SwiftEmailCore", "SwiftEmailProviders", "SwiftEmailMocks"]
        ),
    ]
)
