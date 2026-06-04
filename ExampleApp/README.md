# CambodiaAddress Example App

A tab-based showcase app demonstrating the whole SDK surface: the drop-in SwiftUI picker,
live offline search, and the UIKit entry point.

## Run it

This folder contains the app **sources** plus a [`project.yml`](./project.yml) so the Xcode
project can be generated reproducibly (the generated `.xcodeproj` is intentionally not
committed).

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen        # once
cd ExampleApp
xcodegen generate
open CambodiaAddressExample.xcodeproj
```

Then pick an iOS 18 simulator and run.

### Option B — Manual

1. In Xcode: **File → New → Project… → iOS App** (SwiftUI), deployment target iOS 18.
2. Delete the generated `ContentView.swift` / `App.swift` and add the files from
   `ExampleApp/Sources/`.
3. **File → Add Package Dependencies… → Add Local…**, choose this repository's root, and add
   the `CambodiaAddress` product to the app target.
4. Run.

## What it shows

Three tabs, one shared `CambodiaAddress.live()` facade injected at the app root:

### 1 · Picker (SwiftUI)
- `CambodiaAddressPicker(selection:)` — cascading Province → District → Commune → Village, with search
- `AddressPickerView` — the standalone completion screen, presented as a sheet
- `.addressLanguage(_:)` — live Khmer/English switching (affects all tabs)
- `AddressFormatter` — turning a selection into `"Doun Penh, Phnom Penh"`

### 2 · Search
- `cambodia.search(_:levels:limit:)` — live offline search as you type (Khmer + English,
  prefix + typo-tolerant fuzzy), with debounce and task cancellation
- Level filter chips (`AdministrativeLevel`), level badges, and full breadcrumb paths
  rendered from `AddressSearchResult.path`
- Tapping a result applies its `path` as a complete `AddressSelection`

### 3 · UIKit
- `CambodiaAddressPickerViewController` — the UIKit entry point, presented modally
  (hosted here via `UIViewControllerRepresentable`, exactly as a UIKit app would
  `present(vc, animated: true)`)
- Sharing the app's repository with the controller via its `repository:` parameter
