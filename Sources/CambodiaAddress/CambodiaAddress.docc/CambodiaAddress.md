# ``CambodiaAddress``

Offline-first Cambodian address picking — Province → District → Commune/Sangkat → Village —
in Khmer and English, for SwiftUI and UIKit.

## Overview

`CambodiaAddressSDK` solves a problem nearly every Cambodian app re-implements: cascading
address selection across the country's four administrative levels, with bilingual names and
fast offline search.

The SDK is **offline-first** (a bundled dataset is the source of truth), built on a clean
modular architecture (Core / Data / Search / UI) with Swift 6 strict concurrency and no
third-party dependencies.

### Quick start

The drop-in SwiftUI picker, bound to an ``AddressSelection``:

```swift
import SwiftUI
import CambodiaAddress

struct CheckoutView: View {
    @State private var address = AddressSelection()

    var body: some View {
        CambodiaAddressPicker(selection: $address)
            .addressLanguage(.khmer)
    }
}
```

Headless lookup and search, via the ``CambodiaAddress`` facade:

```swift
let cambodia = CambodiaAddress.live()
let provinces = try await cambodia.provinces()
let results   = try await cambodia.search("ដូនពេញ")
let line      = cambodia.format(address) // "Doun Penh, Phnom Penh"
```

## Topics

### Getting started

- ``CambodiaAddress``
- ``AddressConfiguration``

### SwiftUI

- ``CambodiaAddressPicker``
- ``AddressPickerView``

### Domain model

- ``AddressSelection``
- ``Province``
- ``District``
- ``Commune``
- ``Village``
- ``LocalizedName``
- ``AdministrativeLevel``

### Search & formatting

- ``AddressSearchEngine``
- ``AddressSearchResult``
- ``AddressFormatter``
- ``AddressLanguage``
