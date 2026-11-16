// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "galva_flutter",
    platforms: [
        // Galva's floor (StoreKit 2).
        .iOS("15.0")
    ],
    products: [
        .library(name: "galva-flutter", targets: ["galva_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // The native Galva SDK, distributed through Swift Package Manager only. It needs Xcode 26
        // or later. Pinned like galva-sdk on Android, so each plugin version ships one tested
        // pair of native SDKs; raise it together with the versions table in README.md.
        .package(url: "https://github.com/Galva-io/galva-ios.git", exact: "1.0.0"),
    ],
    targets: [
        .target(
            name: "galva_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Galva", package: "galva-ios"),
            ]
            // No privacy manifest of its own: the plugin collects nothing beyond what the Galva
            // SDK declares in its manifest, which Xcode merges into the app's privacy report.
        )
    ]
)
