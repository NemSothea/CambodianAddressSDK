# CambodiaAddress Example App

A small SwiftUI app demonstrating the SDK: the drop-in picker, a formatted result, a
Khmer/English toggle, and the standalone screen presented as a sheet.

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
2. Delete the generated `ContentView.swift` / `App.swift` and add the two files from
   `ExampleApp/Sources/`.
3. **File → Add Package Dependencies… → Add Local…**, choose this repository's root, and add
   the `CambodiaAddress` product to the app target.
4. Run.

## What it shows

- `CambodiaAddressPicker(selection:)` — cascading Province → District → Commune → Village, with search
- `.addressLanguage(_:)` — live Khmer/English switching
- `AddressPickerView` — the standalone completion screen
- `AddressFormatter` — turning a selection into `"Doun Penh, Phnom Penh"`
- `.cambodiaAddress(.live())` — injecting the SDK at the app root
