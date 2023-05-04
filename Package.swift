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
             // .package(url: /* package url */, from: "1.0.0"),
        ],
        targets: [
            .target(
                name: "REES46",
                path: "REES46/Classes",
                resources: [
                    .process("Resources")
                ]
        )
    ]
)
