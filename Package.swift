// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "plug",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(
            name: "Plug",
            targets: ["Plug"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.2.2"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.1.0")
    ],
    targets: [
        .macro(
            name: "PlugMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Plug",
            dependencies: ["PlugMacros", .product(name: "Crypto", package: "swift-crypto")]
        ),
        .testTarget(
            name: "PlugTests",
            dependencies: ["Plug", "PlugMacros",
                .product(name: "MacroTesting", package: "swift-macro-testing")
            ]
        ),
        .target(
            name: "ExamplePlugin",
            dependencies: ["Plug"])
    ]
)
