# CambodiaAddressSDK — Build Plan

Implementation roadmap for the architecture defined in [`ARCHITECTURE.md`](./ARCHITECTURE.md).
Built **phase by phase, bottom-up** (Domain → Data → Search → UI → Facade), so every layer compiles
and is tested before the layer above it depends on it.

**Toolchain:** Swift 6.1.2 · Xcode 16.4 · iOS 18+ · `swiftLanguageModes: [.v6]` · `import Testing`.

**Global rules (every phase):**
- After each phase: `swift build` and `swift test` must pass with **zero warnings** under Swift 6 strict concurrency.
- Public types get doc comments. Everything not part of the public API is `internal`.
- No third-party dependencies in shipping targets.
- Commit at the end of each green phase with a conventional-commit message.

---

## Phase 0 — Bootstrap  ✅ acceptance: `swift build` succeeds on an empty package

- [ ] `git init` this folder as its **own** repository (currently nested in the `Desktop` repo).
- [ ] Add `.gitignore` (Swift/SPM/Xcode/macOS).
- [ ] Write `Package.swift`: 5 source targets + 5 test targets, `defaultLocalization: "en"`, `platforms: [.iOS(.v18)]`, `swiftLanguageModes: [.v6]`.
- [ ] Create empty source dirs with a placeholder file per target so SPM resolves.
- [ ] Verify `swift build` and `swift test` run (zero tests OK).

## Phase 1 — Core / Domain  ✅ acceptance: models decode; formatter + selection logic unit-tested

- [ ] `AdministrativeLevel`, `AddressLanguage` (`.khmer/.english/.system`), `LocalizedName` (+ `resolved(for:)`).
- [ ] `Province`, `District` (+ `DistrictType`), `Commune` (+ `CommuneType`), `Village` — all `Codable, Sendable, Identifiable, Hashable`, keyed by NCDD `code`.
- [ ] `AddressSelection` with `isComplete`, `deepestLevel`, and downstream-reset helpers.
- [ ] `AddressCode` helpers (parent-code derivation, validation).
- [ ] `AddressError` (typed errors: notLoaded, decodeFailed, notFound, etc.).
- [ ] `AddressFormatter` (selection → string, KM/EN, ordered village→province).
- [ ] Protocols: `AddressRepository`, `AddressDataSource`.
- [ ] **Tests:** decode round-trip, `resolved(for:)`, formatter output (KM + EN), selection invariants & reset.

## Phase 2 — Data  ✅ acceptance: sample dataset loads via repository; parent→child linkage correct

- [ ] `AddressDataset` DTO (short keys `p/d/c`, maps to domain) + `DatasetVersion`.
- [ ] `BundledJSONDataSource`, `InMemoryDataSource`.
- [ ] `AddressStore` (actor): lazy single-load, builds parent→children index dictionaries + hands dataset to search.
- [ ] `DefaultAddressRepository` (final, Sendable) composing datasource + store.
- [ ] Ship a **small multi-province sample** `cambodia_address.json` (placeholder until real data arrives).
- [ ] `RemoteAddressDataSource` stub (v3 seam, throws `notImplemented`).
- [ ] **Tests:** decode the sample, index correctness, lazy load runs once, linkage (province→district→commune→village), unknown-code errors.

## Phase 3 — Search  ✅ acceptance: KM/EN prefix + fuzzy correct; p95 < 16 ms on 25k synthetic set

- [ ] `KhmerNormalizer` (NFC, zero-width strip, diacritic/case fold on Latin).
- [ ] `Trie`, inverted token index, `Fuzzy` (bounded Damerau-Levenshtein).
- [ ] `AddressSearchEngine` + `AddressSearchResult` (with full breadcrumb `path`).
- [ ] Ranking: exact > prefix > fuzzy, then by level; capped at `searchLimit`.
- [ ] Wire `repository.search(...)` to the engine.
- [ ] **Tests:** Khmer normalization edge cases (golden table), prefix correctness, fuzzy distance bounds, ranking order, **`.timeLimit` performance test** on synthetic 25k.

## Phase 4 — UI  ✅ acceptance: previews render; view-model state transitions tested

- [ ] `AddressPickerViewModel` (`@Observable`, `@MainActor`): select province → load districts → reset downstream; search debounce; validation.
- [ ] SwiftUI: `CambodiaAddressPicker(selection:)`, `AddressPickerView(onComplete:)`, `LevelListView`, `SearchBar`.
- [ ] `AddressEnvironment` (EnvironmentKey) + `.cambodiaAddress(_:)` / `.addressLanguage(_:)` modifiers.
- [ ] `Localizable.xcstrings` (KM + EN UI chrome).
- [ ] Accessibility, Dynamic Type, Dark Mode verified in previews.
- [ ] `CambodiaAddressPickerViewController` (UIKit wrapper via `UIHostingController`).
- [ ] **Tests:** `@MainActor` view-model tests with a `FakeAddressRepository`; debounce; reset cascade; validation.

## Phase 5 — Facade + umbrella  ✅ acceptance: one-liner `CambodiaAddress.live()` works end-to-end

- [ ] `CambodiaAddress` composition root: `.live(configuration:)` wiring datasource → store → search → repository.
- [ ] `Exports.swift` (`@_exported import`) so consumers import one module.
- [ ] Headless facade methods (`provinces()`, `search()`, `formatter`).
- [ ] **Tests:** integration test against the bundled sample through the facade.

## Phase 6 — Example app, docs, CI  ✅ acceptance: example app builds; CI green; docs generate

- [ ] `ExampleApp/` Xcode project consuming the package (SwiftUI + UIKit screens).
- [ ] `CambodiaAddress.docc` catalog + symbol docs.
- [ ] GitHub Actions: `swift build` + `swift test` on macOS, matrix on iOS sim.
- [ ] `README.md`: badges, install (SPM), quick start, screenshots, roadmap.
- [ ] Tag `v1.0.0`.

---

## Milestones

| Milestone | Phases | Outcome |
|---|---|---|
| **M1 — Headless SDK** | 0–2 | Lookup works in code, offline. No UI. |
| **M2 — Searchable** | 3 | KM/EN search over the dataset. |
| **M3 — Drop-in UI** | 4–5 | `CambodiaAddressPicker(selection:)` works in any app. |
| **M4 — Shippable v1** | 6 | Example app, docs, CI, tagged release. |

## How to execute

Run the **`/build-address-sdk`** skill. With no argument it detects the current phase from what's
on disk and builds the next one. Pass a phase to target it directly: `/build-address-sdk phase 3`.
The skill enforces the global rules above and verifies (`swift build` + `swift test`) before reporting done.
