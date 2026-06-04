# CambodiaAddressSDK

[![CI](https://github.com/NemSothea/CambodianAddressSDK/actions/workflows/ci.yml/badge.svg)](https://github.com/NemSothea/CambodianAddressSDK/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)
![Platforms](https://img.shields.io/badge/platform-iOS%2018%2B-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

A production-ready Swift Package for picking Cambodian administrative addresses:

**Province → District → Commune/Sangkat → Village**

Offline-first, Khmer/English, SwiftUI-first with UIKit support, and zero third-party dependencies.

```swift
@State private var address = AddressSelection()

CambodiaAddressPicker(selection: $address)
    .addressLanguage(.khmer)
```

## Features

- 🗺️ Full 4-level hierarchy: Province, District, Commune/Sangkat, Village
- 📴 **Offline-first** — bundled dataset, works in airplane mode
- 🔎 Fast offline **search** (Khmer + English, prefix + typo-tolerant fuzzy)
- 🇰🇭 Bilingual place names (Khmer/English) carried in the data
- 🧩 SwiftUI **and** UIKit components
- 🏗️ Clean modular architecture (Core / Data / Search / UI), MVVM, Swift 6 concurrency
- ✅ 85 unit + integration tests, no third-party dependencies
- 🔌 Future-proof: API-sync seam (`RemoteAddressDataSource`) ready for v3

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and enter:

```
https://github.com/NemSothea/CambodianAddressSDK.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NemSothea/CambodianAddressSDK.git", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "CambodiaAddress", package: "CambodianAddressSDK")
    ])
]
```

> Need only lookups, no UI? Depend on the lighter `CambodiaAddressCore` product instead.

## Usage

### 1. Drop-in SwiftUI picker

```swift
import SwiftUI
import CambodiaAddress

struct CheckoutView: View {
    @State private var address = AddressSelection()

    var body: some View {
        CambodiaAddressPicker(selection: $address)
            .addressLanguage(.khmer)            // or .english / .system
    }
}
```

### 2. Standalone screen

```swift
AddressPickerView { address in
    save(address)
}
```

### 3. Headless (no UI)

```swift
let cambodia = CambodiaAddress.live()

let provinces = try await cambodia.provinces()
let districts = try await cambodia.districts(inProvince: "12")
let results   = try await cambodia.search("ដូនពេញ")        // Khmer or English
let line      = cambodia.format(address)                   // "Doun Penh, Phnom Penh"
```

### 4. UIKit

```swift
let vc = CambodiaAddressPickerViewController { address in
    print(address)
}
present(vc, animated: true)
```

### Inject configuration

```swift
ContentView()
    .cambodiaAddress(.live(.init(language: .khmer, searchLimit: 20)))
```

## Architecture

Five modules in a strict dependency line — UI depends on abstractions, never on concrete data loading:

```
CambodiaAddress (umbrella facade + composition root)
   ├── CambodiaAddressUI      (SwiftUI + UIKit + @Observable view model)
   ├── CambodiaAddressData    (datasources, AddressStore actor, repository)
   ├── CambodiaAddressSearch  (Khmer normalizer, prefix index, fuzzy)
   └── CambodiaAddressCore    (domain models, protocols — Foundation only)
```

See [`ARCHITECTURE.md`](./ARCHITECTURE.md) for the full design and [`BUILD_PLAN.md`](./BUILD_PLAN.md) for how it was built.

## Data

The SDK ships with the **full NCDD dataset** — 25 provinces, 210 districts, 1,652
communes/sangkats, and **14,578 villages** — bundled offline (~1.3 MB). To swap in an updated
gazetteer, replace `Sources/CambodiaAddressData/Resources/cambodia_address.json` (same schema)
— no code changes required. The format:

```jsonc
{
  "version": "2026.06",
  "provinces": [{ "code": "12", "km": "ភ្នំពេញ", "en": "Phnom Penh" }],
  "districts": [{ "code": "1201", "p": "12", "km": "ដូនពេញ", "en": "Doun Penh", "t": "khan" }],
  "communes":  [{ "code": "120103", "d": "1201", "km": "…", "en": "…", "t": "sangkat" }],
  "villages":  [{ "code": "12010301", "c": "120103", "km": "…", "en": "…" }]
}
```

Codes follow the NCDD convention (province 2 digits → village 8 digits); a child's code is prefixed by its parent's.

## Example app

A runnable demo lives in [`ExampleApp/`](./ExampleApp). See its [README](./ExampleApp/README.md) to generate and run it.

## Requirements

- iOS 18+
- Swift 6 / Xcode 16+

## Roadmap

- **v1** ✅ Province/District/Commune/Village, offline data, search, SwiftUI + UIKit
- **v2** Address formatting refinements, more locales
- **v3** GPS → nearest commune, postal codes, API sync (`RemoteAddressDataSource`)
- **v4** Map integration, reverse geocoding, validation

## Acknowledgements

The bundled administrative dataset is derived from [**pumi**](https://github.com/dwilkie/pumi)
(MIT licensed), which compiles geodata from the **NCDD** (National Committee for Sub-National
Democratic Development) gazetteer — <http://db.ncdd.gov.kh/gazetteer>. Khmer names, romanized
names, and NCDD codes originate there. Thanks to those projects for maintaining open Cambodian
geodata.

## License

MIT — see [LICENSE](./LICENSE). The bundled data derives from pumi (MIT) / NCDD; see Acknowledgements.
