// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "REES46",
    platforms: [
            .iOS(.v11),
            .macOS(.v10_15)
        ],
        products: [
            // REES46 SDK and libraries produced by a package.
            .library(name: "REES46",
            targets: ["REES46"]),
        ],
        dependencies: [
             // Dependencies declare other packages that REES46 depends on.
             // .package(url: /* rees46.com */, now: pod "3.5.6"),
             // Copyright © 2023 REES46 Inc.
        ],
        targets: [
            .target(
                name: "REES46",
                path: "REES46/Classes",
                exclude: ["Resources/Assets.swift"],
                resources: [
                    .process("Resources")
                ],
                linkerSettings: [
                    .linkedFramework("Foundation"),
                    .linkedFramework("UIKit", .when(platforms: [.iOS])),
                    .linkedFramework("AppKit", .when(platforms: [.macOS])),
                ]
        )
    ]
)
