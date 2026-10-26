// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "REES46",
    platforms: [
            .iOS(.v12)
        ],
        products: [
            // REES46 SDK and libraries produced by a package.
            .library(name: "REES46",
            targets: ["REES46"]),
        ],
        dependencies: [],
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
                    .linkedFramework("UIKit"),
                ]
        )
    ]
)
