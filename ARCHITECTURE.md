# CambodiaAddressSDK — Architecture

> Production-ready Swift Package for Cambodian administrative addresses
> (Province → District → Commune/Sangkat → Village).
>
> Swift 6 · iOS 18+ · SwiftUI-first · Offline-first · MVVM · Modular · No third-party deps · Khmer/English · API-sync ready.

This document is the **contract** for the SDK. Code is illustrative (signatures, not full bodies) so we agree on shape before implementing v1.

---

## 0. Design principles

1. **Offline-first.** The bundled dataset is the source of truth. Network sync (v3) is an *optimization*, never a dependency. The SDK fully works with the device in airplane mode.
2. **Layered & dependency-inverted.** UI depends on Domain abstractions, never on concrete data loading. Data flows up; dependencies point down toward Domain.
3. **Value semantics + `Sendable` everywhere.** Models are immutable structs. Concurrency is explicit (`actor` for shared mutable caches, `@MainActor` for view models).
4. **No singletons in the core.** A composition root assembles dependencies; everything else receives them. (One *optional* convenience facade exists for app developers who don't want DI.)
5. **Data-level i18n, not just UI i18n.** Khmer and English names live *in the model*, because they are data, not UI strings. UI strings (button titles, placeholders) use a String Catalog.
6. **Stable codes are the identity.** Identity = official NCDD code (string), not array index. This keeps selections valid across dataset updates.

---

## 1. Folder structure

```
CambodiaAddressSDK/
├── Package.swift
├── README.md
├── ARCHITECTURE.md                     ← this file
├── Sources/
│   ├── CambodiaAddressCore/            ← Domain: models, protocols, errors, formatting
│   │   ├── Models/
│   │   │   ├── AdministrativeLevel.swift
│   │   │   ├── LocalizedName.swift
│   │   │   ├── Province.swift
│   │   │   ├── District.swift
│   │   │   ├── Commune.swift
│   │   │   ├── Village.swift
│   │   │   ├── AddressSelection.swift
│   │   │   └── AddressCode.swift
│   │   ├── Protocols/
│   │   │   ├── AddressRepository.swift
│   │   │   └── AddressDataSource.swift
│   │   ├── Formatting/
│   │   │   └── AddressFormatter.swift
│   │   ├── Localization/
│   │   │   └── AddressLanguage.swift
│   │   └── Errors/
│   │       └── AddressError.swift
│   │
│   ├── CambodiaAddressData/            ← Data: datasources + repository impl + resources
│   │   ├── Repository/
│   │   │   └── DefaultAddressRepository.swift
│   │   ├── DataSources/
│   │   │   ├── BundledJSONDataSource.swift
│   │   │   ├── InMemoryDataSource.swift          (testing + previews)
│   │   │   └── RemoteAddressDataSource.swift      (v3 stub)
│   │   ├── Cache/
│   │   │   └── AddressStore.swift                 (actor: decoded, indexed cache)
│   │   ├── DTO/
│   │   │   └── AddressDataset.swift               (Codable wire format)
│   │   └── Resources/
│   │       └── cambodia_address.json              (provided later)
│   │
│   ├── CambodiaAddressSearch/          ← Search: index + normalization + query engine
│   │   ├── SearchIndex.swift
│   │   ├── Trie.swift
│   │   ├── KhmerNormalizer.swift
│   │   ├── Fuzzy.swift
│   │   └── AddressSearchEngine.swift
│   │
│   ├── CambodiaAddressUI/              ← Presentation: SwiftUI + UIKit + view models
│   │   ├── ViewModels/
│   │   │   └── AddressPickerViewModel.swift
│   │   ├── SwiftUI/
│   │   │   ├── CambodiaAddressPicker.swift        (binding-based, drop-in)
│   │   │   ├── AddressPickerView.swift            (standalone screen)
│   │   │   ├── LevelListView.swift
│   │   │   └── SearchBar.swift
│   │   ├── UIKit/
│   │   │   └── CambodiaAddressPickerViewController.swift
│   │   ├── Environment/
│   │   │   └── AddressEnvironment.swift           (SwiftUI Environment plumbing)
│   │   └── Resources/
│   │       └── Localizable.xcstrings
│   │
│   └── CambodiaAddress/                ← Umbrella facade: composition root + re-exports
│       ├── CambodiaAddress.swift
│       └── Exports.swift                          (@_exported import …)
│
├── Tests/
│   ├── CambodiaAddressCoreTests/
│   ├── CambodiaAddressDataTests/
│   ├── CambodiaAddressSearchTests/
│   └── CambodiaAddressUITests/
│
├── ExampleApp/                         ← Separate Xcode project consuming the package
│
└── Documentation/
    └── CambodiaAddress.docc/
```

---

## 2. Package structure (targets)

Five library targets in a strict dependency line. Modularity lets a consumer who only needs lookup (no UI) avoid pulling in SwiftUI, and lets the search engine evolve independently.

```
CambodiaAddress (umbrella, public)
        │  depends on ↓
   ┌────┴───────────────┐
   ▼                    ▼
CambodiaAddressUI   (re-exports Core)
   │  depends on ↓
   ├──────────────┬─────────────────┐
   ▼              ▼                 ▼
CambodiaAddress  CambodiaAddress  CambodiaAddressCore
   Data            Search
   │                 │
   └────────┬────────┘
            ▼
   CambodiaAddressCore   (no dependencies — pure domain)
```

| Target | Depends on | Links | Why separate |
|---|---|---|---|
| `CambodiaAddressCore` | — | Foundation | Pure domain. No UI, no I/O. Maximally testable & reusable (e.g. a server-side or CLI consumer). |
| `CambodiaAddressData` | Core | Foundation | Owns JSON decoding, caching actor, the bundled resource, and the future remote sync. Swappable. |
| `CambodiaAddressSearch` | Core | Foundation | Heavy algorithmic code (trie, fuzzy, Khmer normalization) isolated and benchmarkable on its own. |
| `CambodiaAddressUI` | Core, Data, Search | SwiftUI, UIKit | All presentation. The only target that imports SwiftUI/UIKit. |
| `CambodiaAddress` | all | — | The friendly front door + composition root. 90% of users import only this. |

```swift
// Package.swift (shape)
let package = Package(
    name: "CambodiaAddressSDK",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "CambodiaAddress",       targets: ["CambodiaAddress"]),       // full
        .library(name: "CambodiaAddressCore",   targets: ["CambodiaAddressCore"]),   // headless
        .library(name: "CambodiaAddressSearch", targets: ["CambodiaAddressSearch"]),
    ],
    targets: [
        .target(name: "CambodiaAddressCore"),
        .target(name: "CambodiaAddressData",
                dependencies: ["CambodiaAddressCore"],
                resources: [.process("Resources/cambodia_address.json")]),
        .target(name: "CambodiaAddressSearch", dependencies: ["CambodiaAddressCore"]),
        .target(name: "CambodiaAddressUI",
                dependencies: ["CambodiaAddressCore", "CambodiaAddressData", "CambodiaAddressSearch"]),
        .target(name: "CambodiaAddress",
                dependencies: ["CambodiaAddressCore", "CambodiaAddressData",
                               "CambodiaAddressSearch", "CambodiaAddressUI"]),
        // + one test target per source target
    ],
    swiftLanguageModes: [.v6]
)
```

---

## 3. Domain models

Every model is `Codable, Sendable, Identifiable, Hashable`. Identity is the official **code** (string), never an index.

```swift
public enum AdministrativeLevel: String, Codable, Sendable, CaseIterable {
    case province, district, commune, village
}

/// Bilingual name carried in the data itself.
public struct LocalizedName: Codable, Sendable, Hashable {
    public let km: String      // ភ្នំពេញ
    public let en: String      // Phnom Penh
    public func resolved(for language: AddressLanguage) -> String
}

public struct Province: Codable, Sendable, Identifiable, Hashable {
    public let id: String          // NCDD code, e.g. "12"  (== code)
    public let code: String
    public let name: LocalizedName
}

public struct District: Codable, Sendable, Identifiable, Hashable {
    public let id: String          // e.g. "1201"
    public let code: String
    public let provinceCode: String   // parent link "12"
    public let name: LocalizedName
    public let type: DistrictType     // .district / .municipality / .khan
}

public struct Commune: Codable, Sendable, Identifiable, Hashable {
    public let id: String          // e.g. "120101"
    public let code: String
    public let districtCode: String   // parent "1201"
    public let name: LocalizedName
    public let type: CommuneType      // .commune / .sangkat
}

public struct Village: Codable, Sendable, Identifiable, Hashable {
    public let id: String          // e.g. "12010101"
    public let code: String
    public let communeCode: String    // parent "120101"
    public let name: LocalizedName
}

/// The user's in-progress / completed selection. This is the SDK's main output value.
public struct AddressSelection: Codable, Sendable, Hashable {
    public var province: Province?
    public var district: District?
    public var commune:  Commune?
    public var village:  Village?

    public var isComplete: Bool { village != nil }
    public var deepestLevel: AdministrativeLevel? { … }
}
```

**Code convention (NCDD):** province = 2 digits, district = 4, commune = 6, village = 8. A child code is prefixed by its parent code, so parent linkage is *derivable* — we still store the explicit `parentCode` for O(1) lookups and resilience to future numbering changes.

---

## 4. Repository layer

The repository is the **only abstraction the UI and the facade know about.** It speaks domain types and async. It hides whether data came from a bundle, a cache, or the network.

```swift
public protocol AddressRepository: Sendable {
    func provinces() async throws -> [Province]
    func districts(inProvince code: String) async throws -> [District]
    func communes(inDistrict code: String) async throws -> [Commune]
    func villages(inCommune code: String) async throws -> [Village]

    // Direct resolution (deep-linking, restoring a saved selection by codes)
    func selection(forVillageCode code: String) async throws -> AddressSelection

    // Search (delegates to CambodiaAddressSearch)
    func search(_ query: String,
                levels: Set<AdministrativeLevel>,
                limit: Int) async throws -> [AddressSearchResult]
}
```

`DefaultAddressRepository` (in Data) composes a `AddressDataSource` + the `AddressStore` cache + an `AddressSearchEngine`. It is `final` and `Sendable`; concurrency-safe because all mutable state is inside the `AddressStore` actor.

```swift
public final class DefaultAddressRepository: AddressRepository {
    public init(dataSource: any AddressDataSource,
                searchEngineFactory: @escaping @Sendable (AddressDataset) -> AddressSearchEngine)
}
```

---

## 5. Data source layer

A `AddressDataSource` produces the raw dataset; it knows nothing about queries or caching.

```swift
public protocol AddressDataSource: Sendable {
    func load() async throws -> AddressDataset      // full snapshot
    var version: DatasetVersion { get async }        // for v3 sync invalidation
}
```

| Implementation | Module | Role |
|---|---|---|
| `BundledJSONDataSource` | Data | Default. Reads `cambodia_address.json` from the module bundle, decodes once. |
| `InMemoryDataSource` | Data | Hand-built datasets for tests, previews, and the small sample we start with. |
| `RemoteAddressDataSource` | Data (v3) | Fetches a newer dataset from an API, validates `version`, hands off to a persistent cache. |
| `CachingDataSource` | Data (v3) | Decorator: returns disk cache if fresh, else falls back to bundle, refreshes from remote in background. |

**`AddressStore` (actor)** — the decoded-and-indexed in-memory cache. Loads lazily on first query, builds parent→children index dictionaries (`[provinceCode: [District]]`, etc.) and hands the dataset to the search engine. Being an `actor` makes concurrent reads from multiple view models safe with zero locks in calling code.

```swift
actor AddressStore {
    func provinces() -> [Province]                          // O(1) after load
    func districts(in provinceCode: String) -> [District]   // O(1) dictionary hit
    // … ensureLoaded() runs the datasource exactly once.
}
```

**Wire format (`AddressDataset` DTO)** — see §"Data file" below. Decoded into domain models behind the datasource boundary so the on-disk shape can change without touching Domain.

---

## 6. Localization strategy

Two distinct concerns, deliberately separated:

| Concern | Where | Mechanism |
|---|---|---|
| **Place names** (ភ្នំពេញ / Phnom Penh) | Domain data | `LocalizedName { km, en }` stored *in* each model. The dataset ships both. `resolved(for:)` picks one. |
| **UI chrome** ("Select a province", "Search", "Clear") | UI module | `Localizable.xcstrings` (String Catalog) with `km` + `en`, `defaultLocalization: "en"`. |

- `AddressLanguage` enum (`.khmer`, `.english`, `.system`) drives which place-name is shown. `.system` reads `Locale.current`.
- Language is injected into view models and threaded into `AddressFormatter`, so the same component renders Khmer or English without re-instantiation.
- Khmer-specific text handling (no spaces between words, Khmer digits option) lives in `AddressFormatter` and `KhmerNormalizer` (search), keeping locale quirks in one place.

---

## 7. Dependency injection strategy

**No DI framework.** A hand-rolled composition root + constructor injection — idiomatic, testable, zero deps.

1. **Composition root:** `CambodiaAddress.live(configuration:)` assembles datasource → store → search engine → repository. This is the *only* place concrete types are named.
2. **Constructor injection:** view models receive `any AddressRepository`. Tests pass a fake; production passes the real one.
3. **SwiftUI Environment:** a configured repository is placed into the SwiftUI `Environment` via a custom `EnvironmentKey`, so deeply nested views resolve it without prop-drilling.

```swift
public struct AddressConfiguration: Sendable {
    public var language: AddressLanguage = .system
    public var dataSource: DataSourceKind = .bundled        // .bundled / .inMemory(dataset) / .remote(url)
    public var searchLimit: Int = 25
}

// SwiftUI:
ContentView()
    .cambodiaAddress(.live(.init(language: .khmer)))   // injects into Environment
```

This keeps the public API a single line for casual users, while power users can build and inject their own `AddressRepository`.

---

## 8. Public API design

Three entry points, increasing control:

**(a) Drop-in binding picker** — the headline API:
```swift
@State private var address = AddressSelection()

CambodiaAddressPicker(selection: $address)
    .addressLanguage(.khmer)
```

**(b) Standalone screen** with completion:
```swift
AddressPickerView { selection in
    save(selection)
}
```

**(c) Headless facade** (no UI — for forms you build yourself, validation, geocoding):
```swift
let cambodia = CambodiaAddress.live()
let provinces = try await cambodia.provinces()
let results   = try await cambodia.search("ដូនពេញ", limit: 10)
let formatted = cambodia.formatter.string(from: selection, language: .english)
// "Phsar Thmei 3, Doun Penh, Phnom Penh"
```

**(d) UIKit:**
```swift
let vc = CambodiaAddressPickerViewController { selection in … }
present(vc, animated: true)
```

API stability rules: public surface is small and code-keyed; adding a level or a field never breaks callers (selections are codes-based). Everything else is `internal`.

---

## 9. Search engine (offline, ~20k villages)

### Architecture
A `SearchIndex` built once at load time (off the main actor), held by the `AddressStore`. Two cooperating structures:

1. **Inverted token index** — `[normalizedToken: [DocumentRef]]` for exact/token matches across all 4 levels (~25k docs total). Memory ~ a few MB.
2. **Prefix trie** — over normalized tokens for incremental prefix search ("ភ្នំ…" / "phn…") as the user types.
3. **Fuzzy fallback** — bounded Damerau-Levenshtein (max distance 1–2) run *only* over trie candidates within an edit neighborhood, never the whole set.

### Khmer normalization (`KhmerNormalizer`)
- Unicode NFC normalization.
- Strip/normalize zero-width spaces & invisible characters (common in Khmer input).
- Optional romanization-tolerant folding for English ("Phnom"/"Phnum").
- Lowercasing + diacritic folding on the Latin side.
This is the single hardest correctness problem; it gets its own type and its own test suite of real-world inputs.

### Algorithms & complexity (n ≈ 25,000 docs)
| Operation | Approach | Time | Notes |
|---|---|---|---|
| Build index | one pass, tokenize + insert | O(n · t) | t = tokens/name (~2). Done once, off main thread. |
| Exact token | dictionary lookup | O(1) avg + O(k) to collect | k = matches |
| Prefix | trie descent + subtree collect | O(p + k) | p = prefix length |
| Fuzzy | candidates from trie, bounded edit distance | O(c · m · d) | c = candidates, capped; m = query len |
| Rank | score by level, prefix-vs-substring, exact-vs-fuzzy | O(k log k) | sort top results only |

Results are capped (`searchLimit`) and ranked: exact > prefix > fuzzy, and within that province > district > commune > village (configurable), so the dropdown stays useful.

```swift
public struct AddressSearchResult: Sendable, Identifiable, Hashable {
    public let id: String              // matched unit code
    public let level: AdministrativeLevel
    public let name: LocalizedName
    public let path: AddressSelection  // full breadcrumb for the match
    public let score: Double
}
```

---

## 10. Testing strategy

Built on **swift-testing** (`import Testing`), the modern Swift 6 framework. One test target per source target.

| Layer | What we test | How |
|---|---|---|
| Core | model decoding, `LocalizedName.resolved`, `AddressFormatter`, code conventions, `AddressSelection` invariants | pure unit tests, no I/O |
| Data | `BundledJSONDataSource` decode, `AddressStore` indexing correctness, parent→child linkage, lazy single-load | `InMemoryDataSource` + a tiny fixture dataset |
| Search | normalization (Khmer edge cases), prefix correctness, fuzzy distance bounds, ranking order, **performance** | golden-input tables + `.timeLimit` performance tests on a synthetic 25k set |
| UI | `AddressPickerViewModel` state transitions (select province → districts load → reset downstream), validation, search debounce | `@MainActor` tests with a fake repository |
| Facade | composition root wires correctly; end-to-end query | integration test against the bundled sample |

Principles:
- **Repository is faked, never mocked with a framework** — hand-written `FakeAddressRepository` returning fixtures.
- **Determinism:** no real network in tests; `RemoteAddressDataSource` tested via an injected `URLProtocol` stub.
- **Performance budget:** search p95 < 16 ms on the full dataset (one frame) — enforced by a timed test so regressions fail CI.
- **Snapshot/UX:** SwiftUI previews double as visual smoke tests; consider point-free SnapshotTesting later (would add a *test-only* dependency — kept out of the shipping product).

---

## Data file (provided later)

The data layer is built against this shape now; you drop in the real `cambodia_address.json` later with zero code changes. Recommended **normalized + parent-keyed** structure (small, fast to index, easy to diff for sync):

```jsonc
{
  "version": "2026.01",                 // for v3 sync invalidation
  "provinces": [{ "code": "12", "km": "ភ្នំពេញ", "en": "Phnom Penh" }],
  "districts": [{ "code": "1201", "p": "12", "km": "ដូនពេញ", "en": "Doun Penh", "t": "khan" }],
  "communes":  [{ "code": "120101", "d": "1201", "km": "…", "en": "…", "t": "sangkat" }],
  "villages":  [{ "code": "12010101", "c": "120101", "km": "…", "en": "…" }]
}
```
Short keys (`p`, `d`, `c`) keep the file small; the DTO maps them to readable model fields. Flat arrays (vs. deep nesting) decode faster and let the `AddressStore` build exactly the indexes it wants. Until you provide it, we ship a small multi-province **sample** + `InMemoryDataSource` so previews and tests run.

---

## Roadmap → architecture mapping

| Version | Feature | Lands in |
|---|---|---|
| v1 | Province/District/Commune/Village + offline JSON | Core, Data, UI |
| v2 | KM/EN search, `AddressFormatter` | Search, Core.Formatting |
| v3 | GPS→nearest commune, postal codes, API sync | new `Geo` module, `RemoteAddressDataSource`, `CachingDataSource` |
| v4 | Map integration, reverse geocoding, validation | `Geo` module + MapKit (kept in a *separate optional product* so the core stays dependency-free) |

Adding v3/v4 introduces **new modules**, never edits to Core's public API — that's the payoff of the layering.

---

## Open decisions for you to confirm before v1 build

1. **Data identity:** confirm NCDD codes as IDs (vs. UUIDs). *Recommended: NCDD codes.*
2. **`District.type` / `Commune.type`:** include Khan/Sangkat/Municipality typing in v1, or flatten? *Recommended: include — it's free and matches reality.*
3. **Search:** ship in v1, or hold for v2 as you listed? Architecture supports either; the module exists regardless.
4. **Min platform:** iOS 18 confirmed (lets us use the latest SwiftUI + `@Observable` + swift-testing cleanly).
5. **Repo:** initialize `CambodiaAddressSDK/` as its **own** git repo (it currently sits inside the `Desktop` repo).
```
