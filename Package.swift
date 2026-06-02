// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CambodiaAddressSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        // Full SDK: models + data + search + UI + facade. Most consumers import this.
        .library(name: "CambodiaAddress", targets: ["CambodiaAddress"]),
        // Headless: domain models + protocols only, no UI. For servers, CLIs, custom forms.
        .library(name: "CambodiaAddressCore", targets: ["CambodiaAddressCore"]),
        // Search engine in isolation, for consumers who index their own data.
        .library(name: "CambodiaAddressSearch", targets: ["CambodiaAddressSearch"]),
    ],
    targets: [
        // MARK: Domain (pure, Foundation-only)
        .target(
            name: "CambodiaAddressCore"
        ),

        // MARK: Data (datasources + repository + bundled resource)
        .target(
            name: "CambodiaAddressData",
            dependencies: ["CambodiaAddressCore"],
            resources: [
                .process("Resources/cambodia_address.json")
            ]
        ),

        // MARK: Search (trie + inverted index + Khmer normalization)
        .target(
            name: "CambodiaAddressSearch",
            dependencies: ["CambodiaAddressCore"]
        ),

        // MARK: UI (SwiftUI + UIKit + view models) — the only target that links UI frameworks
        .target(
            name: "CambodiaAddressUI",
            dependencies: [
                "CambodiaAddressCore",
                "CambodiaAddressData",
                "CambodiaAddressSearch",
            ]
        ),

        // MARK: Umbrella facade + composition root
        .target(
            name: "CambodiaAddress",
            dependencies: [
                "CambodiaAddressCore",
                "CambodiaAddressData",
                "CambodiaAddressSearch",
                "CambodiaAddressUI",
            ]
        ),

        // MARK: Tests — one target per source target
        .testTarget(
            name: "CambodiaAddressCoreTests",
            dependencies: ["CambodiaAddressCore"]
        ),
        .testTarget(
            name: "CambodiaAddressDataTests",
            dependencies: ["CambodiaAddressData"]
        ),
        .testTarget(
            name: "CambodiaAddressSearchTests",
            dependencies: ["CambodiaAddressSearch"]
        ),
        .testTarget(
            name: "CambodiaAddressUITests",
            dependencies: ["CambodiaAddressUI"]
        ),
        .testTarget(
            name: "CambodiaAddressTests",
            dependencies: ["CambodiaAddress"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
