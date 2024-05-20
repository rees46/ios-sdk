// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PersonaClick",
    platforms: [
            .iOS(.v11),
            .macOS(.v10_15)
        ],
        products: [
            // PersonaClick SDK and libraries produced by a package.
            .library(name: "PersonaClick",
            targets: ["PersonaClick"]),
        ],
        dependencies: [
             // Dependencies declare other packages that PersonaClick depends on.
             // .package(url: /* personaClick.com */, now: pod "3.6.7"),
             // Copyright © 2023 PersonaClick Inc.
        ],
        targets: [
            .target(
                name: "PersonaClick",
                path: "PersonaClick/Classes",
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
