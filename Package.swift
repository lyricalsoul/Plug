// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Plug",
    platforms: [.macOS(.v14), .iOS(.v15), .watchOS(.v8), .tvOS(.v15), .macCatalyst(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Plug",
            targets: ["Plug"]),
        // dylib ExamplePlign for testing only
        .library(
            name: "ExamplePlugin",
            type: .dynamic,
            targets: ["ExamplePlugin"]),
        .executable(
            name: "ExampleApp",
            targets: ["ExampleApp"]),

    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        // test dependencies
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.2.2"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        .macro(
            name: "PlugMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Plug",
            dependencies: ["PlugMacros"]),
        .testTarget(
            name: "PlugTests",
            dependencies: ["Plug", "PlugMacros",
                .product(name: "MacroTesting", package: "swift-macro-testing")
            ]),
        .target(
            name: "ExamplePlugin",
            dependencies: ["Plug"]),
        .executableTarget(
            name: "ExampleApp",
            dependencies: ["Plug"]),
    ]
)
