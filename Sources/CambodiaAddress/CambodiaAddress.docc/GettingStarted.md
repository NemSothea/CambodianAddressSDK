# Getting started

Add the package, drop in the picker, and read back a complete address.

## Overview

The SDK ships everything you need for Cambodian address entry: the full
Province → District → Commune/Sangkat → Village dataset (offline, bundled),
a cascading SwiftUI picker, offline Khmer/English search, and a formatter.

### Install

In Xcode, **File → Add Package Dependencies…** and enter:

```
https://github.com/NemSothea/CambodianAddressSDK.git
```

Add the `CambodiaAddress` product to your app target. It re-exports all the
modules — one `import CambodiaAddress` is all you need.

### Drop in the picker

Bind ``CambodiaAddressPicker`` to an ``AddressSelection``. No setup required —
by default it reads the bundled offline dataset and follows the system locale:

```swift
import SwiftUI
import CambodiaAddress

struct CheckoutView: View {
    @State private var address = AddressSelection()

    var body: some View {
        Form {
            CambodiaAddressPicker(selection: $address)

            if address.isComplete {
                Text(AddressFormatter().string(from: address))
            }
        }
    }
}
```

``AddressSelection`` is the SDK's primary output value: it carries the chosen
``Province``, ``District``, ``Commune``, and ``Village``, and reports
`isComplete` once all four levels are filled.

### The standalone screen

``AddressPickerView`` wraps the picker in a navigation stack with a **Done**
button — present it as a sheet or push it:

```swift
.sheet(isPresented: $picking) {
    AddressPickerView(initialSelection: address) { selected in
        address = selected
        picking = false
    }
}
```

### Configure once, inject everywhere

For app-wide control, build a ``CambodiaAddress`` facade and inject it at the
root. Every picker in the subtree shares the same repository and language:

```swift
@main
struct MyApp: App {
    @State private var cambodia = CambodiaAddress.live(
        .init(language: .khmer, searchLimit: 10)
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .cambodiaAddress(cambodia)
        }
    }
}
```

To switch only the display language for a subtree, use `addressLanguage(_:)`:

```swift
CambodiaAddressPicker(selection: $address)
    .addressLanguage(.khmer)
```

### Headless use

No UI required — the facade exposes the full lookup API:

```swift
let cambodia  = CambodiaAddress.live()
let provinces = try await cambodia.provinces()
let districts = try await cambodia.districts(inProvince: "12") // Phnom Penh
let selection = try await cambodia.selection(forVillageCode: "01020304")
let line      = cambodia.format(selection)
```

## See Also

- <doc:Search>
- <doc:UIKit>
- <doc:Configuration>
