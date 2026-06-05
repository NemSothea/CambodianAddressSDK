# Changelog

All notable changes to CambodiaAddressSDK are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v1.4.1] — 2026-06-05

### Documentation
- Added real screenshots and animated GIFs to the README (all five `TODO` placeholders filled)
- Hero GIF: full Province → District → Commune → Village picker flow
- Search GIF: live offline search typing `"krang leav"` with results updating in real time
- Screenshots: `CambodiaAddressPicker` in a SwiftUI Form, `AddressPickerView` sheet, `CambodiaAddressPickerViewController` (UIKit)
- Added `DemoCapture.swift` UITest to `ExampleApp` — re-runnable asset capture for future updates

---

## [v1.4.0] — 2026-06-05

### Fixed
- **`BundledJSONDataSource`** — removed unreliable `url.resourceValues(forKeys: [.fileSizeKey])` pre-flight size check, which silently no-ops on sandboxed and virtual filesystems. The post-read `data.count` guard is now the sole authoritative enforcement point.
- **`AddressSearchEngine`** — moved the `maxQueryLength` truncation clamp from the shared `KhmerNormalizer` utility into `AddressSearchEngine.search()`, the correct layer (user-query entry point). Indexing no longer hits the clamp.
- **`AddressStore`** — `districts(inProvince:)`, `communes(inDistrict:)`, and `villages(inCommune:)` now throw `AddressError.notFound` for genuinely unknown parent codes instead of silently returning `[]`. Callers can now distinguish "valid empty list" from "unrecognised code", consistent with `selection(forVillageCode:)`.
- **`DatasetCache`** — `read()` now routes through a new `DatasetDecoding.decodeDataset()` method for consistent `AddressError.decodingFailed` error mapping instead of a bare `JSONDecoder` call. Added `readAsync()` which offloads blocking file I/O to `DispatchQueue.global(qos: .userInitiated)` so the Swift cooperative thread pool is not stalled.
- **`CachingDataSource`** — `bestAvailable()`, `version`, and `refresh()` all use `await cache.readAsync()`.

### Tests
- `unknownParentReturnsEmpty` → `unknownParentThrowsNotFound` (reflects new throwing contract)
- Query-clamp coverage moved from `KhmerNormalizerTests` to `AddressSearchEngineTests.clampsOverlongQuery`
- 138 tests, zero warnings under Swift 6 strict concurrency

---

## [v1.3.0] — 2026-06-04

### Added
- **DoS hardening** — `BundledJSONDataSource` now rejects files larger than 64 MB (`payloadTooLarge`).
- **Query clamping** — `KhmerNormalizer.normalize()` truncates inputs to 500 grapheme clusters before processing, preventing unbounded work on adversarial multi-MB strings.
- **Strict broken-chain detection** — `AddressStore.selection(forVillageCode:)` throws `notFound(code: villageCode)` on any broken parent link (missing commune, district, or province), always using the originally-requested village code.

### Fixed (code-review findings 1–4)
- **`SearchIndex`** — document-building loops now skip villages, communes, and districts with missing parents (guard-let instead of flatMap), keeping the index consistent with `AddressStore`'s strict selection policy.
- **`CachingDataSource.version`** — was calling `bestAvailable()` (full dataset decode); now calls `fallback.version` (lightweight decode), as intended.
- **`AddressError.notFound`** — broken-chain guards in `selection(forVillageCode:)` previously threw the *parent's* code; fixed to always throw the originally-queried `villageCode`.
- **`KhmerNormalizer.normalize()`** — replaced `input.count > max ? prefix : input` (O(n) traversal) with unconditional `String(input.prefix(max))` (O(k)).

---

## [v1.2.0] — 2026-06-03

### Added
- **Multi-locale place names** — `LocalizedName` now carries an optional `additional: [String: String]` map for arbitrary extra locales (`fr`, `zh`, etc.). Wire format: `"i18n": { "fr": "…", "zh": "…" }`. Resolution falls back gracefully (`locale → en → km`).
- **Khmer-numeral formatting** — `AddressFormatter` accepts a `numerals:` parameter (`.arabic` / `.khmer` / `.automatic`). `.automatic` renders Khmer digits when the resolved language is Khmer. Handles district/village numeric suffixes (e.g., `ផ្សារថ្មីទី ៣`).
- New `AddressLanguage.locale(_:)` case for arbitrary BCP 47 locale tags.

---

## [v1.1.0] — 2026-06-02

### Added
- **`RemoteAddressDataSource`** — fetches a dataset from any HTTPS endpoint. Enforces HTTPS-only by default (opt-out via `allowsInsecureHTTP`), validates HTTP status, and enforces a configurable response-size cap (`maximumResponseBytes`, default 16 MB).
- **`CachingDataSource`** — offline-first decorator: serves the freshest on-device snapshot (cache ≥ bundle version wins), then optionally refreshes from the remote in a detached background task. The update is available on the next launch.
- **`DatasetCache`** — atomic disk persistence (`Data.write(options: .atomic)`) with a default location under `<Caches>/CambodiaAddressSDK/dataset.json`.
- `AddressDataSource.version` computed property — lightweight dataset version check without a full decode.
- New `AddressError` cases: `.network`, `.resourceNotFound`, `.insecureEndpoint`, `.invalidResponse`, `.notImplemented`.
- `CambodiaAddress.live(_:)` accepts a `dataSource: .synced(url)` configuration option.

---

## [v1.0.2] — 2026-06-01

### Fixed
- **Picker concurrency** — `AddressPickerViewModel` selection and search operations were racing under rapid user input. Fixed with serial task cancellation and stale-result guards (`generation` counter).
- **Inbound binding sync** — `CambodiaAddressPicker` now correctly adopts external `selection` changes pushed into the binding (e.g., programmatic reset or pre-seeded draft) without re-echoing its own outbound changes.

---

## [v1.0.0] — 2026-05-31 (initial release)

### Added
- Full **NCDD gazetteer** bundled: 25 provinces, 210 districts, 1,652 communes/sangkats, 14,578 villages.
- **`CambodiaAddressCore`** — domain models (`Province`, `District`, `Commune`, `Village`, `AddressSelection`), `AddressRepository` protocol, `AddressFormatter`, `AdministrativeLevel`.
- **`CambodiaAddressData`** — `BundledJSONDataSource`, `AddressStore` actor (lazy single-load, concurrent-safe), `DefaultAddressRepository`, `InMemoryDataSource`.
- **`CambodiaAddressSearch`** — `KhmerNormalizer` (NFC, zero-width strip, Latin diacritic fold), `SearchIndex` (sorted-array prefix + inverted token index), Damerau-Levenshtein fuzzy matching, `AddressSearchEngine`.
- **`CambodiaAddressUI`** — `CambodiaAddressPicker` (drop-in SwiftUI binding picker), `AddressPickerView` (standalone screen), `CambodiaAddressPickerViewController` (UIKit), `AddressPickerViewModel` (`@MainActor @Observable`).
- **`CambodiaAddress`** — umbrella facade, `CambodiaAddress.live()` composition root, `.cambodiaAddress(_:)` / `.addressLanguage(_:)` SwiftUI environment modifiers.
- Swift 6 strict concurrency throughout. Zero third-party dependencies in shipping targets.
- GitHub Actions CI, DocC documentation, MIT license.
