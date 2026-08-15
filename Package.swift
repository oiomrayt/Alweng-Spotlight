// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpotlightEnglish",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "SpotlightEnglish", targets: ["SpotlightEnglish"]),
    ],
    targets: [
        .executableTarget(
            name: "SpotlightEnglish",
            path: "Sources/SpotlightEnglish",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
