# CambodiaAddressSDK

[![CI](https://github.com/NemSothea/CambodianAddressSDK/actions/workflows/ci.yml/badge.svg)](https://github.com/NemSothea/CambodianAddressSDK/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-DocC-blue.svg)](https://nemsothea.github.io/CambodianAddressSDK/documentation/cambodiaaddress)
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
- 🇰🇭 Bilingual place names (Khmer/English) in the data — plus arbitrary extra locales with fallback
- 🧩 SwiftUI **and** UIKit components
- 🏗️ Clean modular architecture (Core / Data / Search / UI), MVVM, Swift 6 concurrency
- ✅ 131 unit + integration tests, no third-party dependencies
- 🔄 Offline-first API sync — refresh the dataset from your own HTTPS endpoint (`.synced`)

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

### Languages & locales

Place names ship in Khmer (`km`) and English (`en`). Request either, or follow the device with
`.system`:

```swift
name.resolved(for: .khmer)          // "ភ្នំពេញ"
name.resolved(for: .system)         // device locale
```

A custom dataset can carry **additional locales** via an optional `i18n` map per unit, addressed
with `.locale(_:)`. Resolution falls back gracefully (`fr → en → km`):

```jsonc
{ "code": "12", "km": "ភ្នំពេញ", "en": "Phnom Penh", "i18n": { "fr": "Phnom Penh", "zh": "金边" } }
```
```swift
name.resolved(for: .locale("zh"))   // "金边"
name.resolved(for: .locale("de"))   // falls back → "Phnom Penh"
```

`AddressFormatter` can render Khmer numerals (`Village ៣`) via `numerals: .khmer` or `.automatic`
(Khmer digits when the language resolves to Khmer).

### Remote sync (v3)

Keep the dataset fresh from your own HTTPS endpoint (serving the same wire format) without ever
going offline. `.synced` is offline-first: it serves the freshest snapshot already on the device
(cached download, or the bundled dataset) and refreshes from the network in the background, so the
update lands on the next launch.

```swift
let cambodia = CambodiaAddress.live(.init(dataSource: .synced(myDatasetURL)))
```

The remote fetch enforces a security contract on untrusted input: **HTTPS-only**, a configurable
**response size cap**, and HTTP-status + decode validation. For full control, build the source
directly:

```swift
let remote = RemoteAddressDataSource(
    endpoint: myDatasetURL,
    configuration: .init(maximumResponseBytes: 16 * 1024 * 1024)
)
let source = CachingDataSource(remote: remote)   // falls back to the bundled dataset
```

## Documentation

Full API documentation (DocC) is hosted at
**[nemsothea.github.io/CambodianAddressSDK](https://nemsothea.github.io/CambodianAddressSDK/documentation/cambodiaaddress)** —
including Getting started, Search, UIKit, and Configuration guides. It rebuilds automatically on every push to `main`.

## Example app

A runnable tab-based showcase lives in [`ExampleApp/`](./ExampleApp):

- **Picker** — the drop-in SwiftUI picker, formatted output, Khmer/English toggle, standalone sheet
- **Search** — live offline search with level filters, badges, and breadcrumb paths
- **UIKit** — `CambodiaAddressPickerViewController` presented the way a UIKit app would

See its [README](./ExampleApp/README.md) to generate (`xcodegen generate`) and run it.

## Requirements

- iOS 18+
- Swift 6 / Xcode 16+

## Roadmap

- **v1** ✅ Province/District/Commune/Village, offline data, search, SwiftUI + UIKit
- **v2** ✅ Multi-locale place names (`+` arbitrary locales via `.locale("fr")` with fallback) · Khmer-numeral formatting
- **v3** API sync ✅ (`RemoteAddressDataSource` + `CachingDataSource`, offline-first) · GPS → nearest commune & postal codes (pending geodata)
- **v4** Map integration, reverse geocoding, validation

## Acknowledgements

The bundled administrative dataset is derived from [**pumi**](https://github.com/dwilkie/pumi)
(MIT licensed), which compiles geodata from the **NCDD** (National Committee for Sub-National
Democratic Development) gazetteer — <http://db.ncdd.gov.kh/gazetteer>. Khmer names, romanized
names, and NCDD codes originate there. Thanks to those projects for maintaining open Cambodian
geodata.

## License

MIT — see [LICENSE](./LICENSE). The bundled data derives from pumi (MIT) / NCDD; see Acknowledgements.
