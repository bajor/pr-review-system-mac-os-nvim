// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PRReviewSystem",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PRReviewSystem", targets: ["PRReviewSystem"])
    ],
    targets: [
        .executableTarget(
            name: "PRReviewSystem",
            path: "Sources/PRReviewSystem",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "PRReviewSystemTests",
            dependencies: ["PRReviewSystem"],
            path: "Tests/PRReviewSystemTests"
        )
    ]
)
