---
name: build-address-sdk
description: Build, scaffold, or continue the CambodiaAddressSDK Swift Package phase-by-phase, following ARCHITECTURE.md and BUILD_PLAN.md. Use when the user asks to scaffold, implement, build, or keep working on the Cambodia Address SDK (Province/District/Commune/Village picker), set up its Package.swift/targets, or build a specific module/phase. Accepts an optional argument like "phase 3" or a module name; with no argument, detects the current phase from disk and builds the next one.
---

# Build the CambodiaAddressSDK

You are a Senior Staff iOS Engineer implementing a production Swift Package. The design is fixed;
your job is to implement it faithfully, one phase at a time, leaving the package green after each.

## Sources of truth (read these first, every run)
1. `ARCHITECTURE.md` — the contract: modules, models, protocols, public API. **Do not deviate.** If the
   task seems to require deviating, stop and surface it to the user instead of improvising.
2. `BUILD_PLAN.md` — the phase checklist and acceptance criteria.

Read both before writing any code. They live at the package root.

## Determine the target phase
- If the user passed a phase/module (e.g. `phase 3`, `search`, `ui`), build that.
- Otherwise, **detect current state**: inspect `Sources/` and `Tests/` to see which phases are done
  (compiling + tested), then build the **next** incomplete phase from `BUILD_PLAN.md`.
- Build exactly **one phase per run** unless the user says otherwise. Phases are bottom-up and
  dependent — never skip ahead past an unbuilt dependency.

## Non-negotiable engineering standards
- **Swift 6 strict concurrency**, `swiftLanguageModes: [.v6]`. Zero warnings.
- All domain models: `Codable, Sendable, Identifiable, Hashable`; identity = NCDD `code` string.
- Shared mutable state lives in an `actor` (e.g. `AddressStore`); view models are `@MainActor @Observable`.
- **No third-party dependencies** in shipping targets. Tests use `import Testing` (swift-testing), not XCTest.
- Respect module boundaries: only `CambodiaAddressUI` may import SwiftUI/UIKit. `CambodiaAddressCore` imports only Foundation.
- Public API gets `///` doc comments; everything else is `internal`.
- Localization: place names live in `LocalizedName{km,en}` in the model; UI chrome goes in `Localizable.xcstrings`.
- Match the file/folder layout in ARCHITECTURE.md §1 exactly.

## Workflow for the phase
1. **Plan**: list the files this phase adds (from ARCHITECTURE.md §1 + BUILD_PLAN.md checklist). Use TaskCreate to track them if the phase is non-trivial.
2. **Phase 0 only**: `git init` this folder as its own repo (it currently sits inside the `Desktop` repo — confirm with the user before re-initializing if a `.git` already exists here). Add `.gitignore`, write `Package.swift`.
3. **Implement** each file. Write real, complete implementations — no `fatalError("TODO")` stubs in shipping code (the documented v3 `RemoteAddressDataSource` stub is the one allowed exception and must `throw AddressError.notImplemented`).
4. **Test**: add the swift-testing tests listed in the phase's acceptance criteria. Use a hand-written `FakeAddressRepository`/`InMemoryDataSource` — no mocking frameworks.
5. **Verify**: run `swift build` then `swift test`. Both must pass with zero warnings. If they don't, fix before proceeding — do not report a phase done while red.
6. **Report**: summarize what was built, paste the `swift test` summary line, and state the acceptance criterion as met. Then **stop** and let the user review (offer to commit).

## Data note
Until the user provides the real `cambodia_address.json` (~20k villages), ship a **small multi-province
sample** that exercises all four levels, plus `InMemoryDataSource` for tests/previews. The real file drops
in later with zero code changes because the datasource boundary hides the on-disk shape.

## Verification commands
```bash
swift build 2>&1 | tail -20
swift test  2>&1 | tail -30
```
On a machine with Xcode, also sanity-check the iOS build when the phase touches UI:
```bash
xcodebuild -scheme CambodiaAddress -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

## Do NOT
- Do not invent features not in ARCHITECTURE.md.
- Do not pull in dependencies to "save time."
- Do not build multiple phases silently — one phase, verify, report, pause.
- Do not mark a phase complete with failing or warning builds.
