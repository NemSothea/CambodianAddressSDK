// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CambodiaAddressSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        // macOS is supported as a host for `swift test` / CI and for headless
        // (Core/Data/Search) consumers. The UI module guards UIKit with #if canImport(UIKit).
        .macOS(.v14),
    ],
    products: [
        // Full SDK: models + data + search + UI + facade. Most consumers import this.
        .library(name: "CambodiaAddress", targets: ["CambodiaAddress"]),
        // Headless: domain models + protocols only, no UI. For servers, CLIs, custom forms.
        .library(name: "CambodiaAddressCore", targets: ["CambodiaAddressCore"]),
        // Search engine in isolation, for consumers who index their own data.
        .library(name: "CambodiaAddressSearch", targets: ["CambodiaAddressSearch"]),
        // GPS → nearest commune + MapKit map picker. Optional: keeps MapKit out of the core SDK.
        .library(name: "CambodiaAddressGeo", targets: ["CambodiaAddressGeo"]),
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

        // MARK: Geo (GPS → nearest commune, haversine, bundled centroids; Foundation-only)
        .target(
            name: "CambodiaAddressGeo",
            dependencies: ["CambodiaAddressCore"],
            resources: [
                .process("Resources/cambodia_communes_geo.json")
            ]
        ),

        // MARK: UI (SwiftUI + UIKit + MapKit view models) — the only target that links UI frameworks
        .target(
            name: "CambodiaAddressUI",
            dependencies: [
                "CambodiaAddressCore",
                "CambodiaAddressData",
                "CambodiaAddressSearch",
                "CambodiaAddressGeo",
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
                "CambodiaAddressGeo",
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
        .testTarget(
            name: "CambodiaAddressGeoTests",
            dependencies: ["CambodiaAddressGeo", "CambodiaAddressCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
