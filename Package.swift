// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AsyncRedux",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AsyncRedux",
            targets: ["AsyncRedux"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.1"),
        .package(url: "https://github.com/groue/Semaphore.git", from: "0.1.0"),
        .package(url: "https://github.com/trevorsheridan/AsyncReactiveSequences.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AsyncRedux",
            dependencies: [
                .product(name: "Semaphore", package: "Semaphore"),
                .product(name: "AsyncReactiveSequences", package: "AsyncReactiveSequences"),
            ]
        ),
        .testTarget(
            name: "AsyncReduxTests",
            dependencies: [
                "AsyncRedux",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
    ]
)
