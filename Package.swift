// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "KeyManagement",
    platforms: [.iOS(.v16), .macOS(.v10_15)],
    products: [
        .library(
            name: "Wallet",
            targets: ["Wallet"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.5.1"),
        .package(url: "https://github.com/Boilertalk/secp256k1.swift.git", from: "0.1.7"),
        .package(url: "https://github.com/zcash-hackworks/MnemonicSwift", from: "2.2.4")
    ],
    targets: [
        .target(name: "Keychain", dependencies: ["Model"]),
        .testTarget(name: "KeychainTests", dependencies: ["Keychain"]),
        .target(name: "Wallet", dependencies: [
            "Keychain",
            "MnemonicSwift",
            "Model",
            .product(name: "secp256k1", package: "secp256k1.swift")
        ]),
        .testTarget(name: "WalletTests", dependencies: ["Wallet"]),
        .target(name: "Model", dependencies: ["CryptoSwift"]),
        .testTarget(name: "ModelTests", dependencies: ["Model"])
    ]
)
