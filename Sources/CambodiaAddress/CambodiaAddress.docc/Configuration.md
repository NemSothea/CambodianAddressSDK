# Configuring the SDK

Choose the data source, language, and search behavior at assembly time.

## Overview

``AddressConfiguration`` is passed to ``CambodiaAddress/live(_:)`` and tunes
the whole stack in one place:

```swift
let cambodia = CambodiaAddress.live(.init(
    language: .khmer,
    dataSource: .bundled,
    searchLimit: 10
))
```

### Language

``AddressConfiguration/language`` sets the default display language for place
names and picker chrome:

- `.khmer` — ភ្នំពេញ
- `.english` — Phnom Penh
- `.system` (default) — follows `Locale.current`

Views can still override per-subtree with `addressLanguage(_:)`.

### Data sources

``AddressConfiguration/DataSource`` selects where the dataset comes from:

| Case | Behavior | Use when |
| --- | --- | --- |
| `.bundled` | The dataset shipped inside the SDK. Default; fully offline. | Almost always — v1/v2 apps. |
| `.inMemory(dataset)` | A caller-supplied `AddressDataset`. | Tests, previews, custom data. |
| `.remote(url)` | Fetch from an HTTPS endpoint on first load. No offline fallback. | Controlled environments only. |
| `.synced(url)` | Offline-first sync: serve the freshest of {cached download, bundled dataset}, refresh from the URL in the background. | Production apps that want server-updated data. |

```swift
// Offline-first with background refresh from your API:
let cambodia = CambodiaAddress.live(.init(
    dataSource: .synced(URL(string: "https://api.example.com/cambodia-address.json")!)
))
```

Remote fetching is HTTPS-only by default, with a response-size cap and timeout.

### Search limit

``AddressConfiguration/searchLimit`` (default 25) caps result counts for every
``CambodiaAddress/search(_:levels:limit:)`` call that doesn't pass an explicit
`limit`.

### Testing with a custom repository

For unit tests or previews, skip `live(_:)` and wrap your own repository:

```swift
let cambodia = CambodiaAddress(repository: StubRepository())
```

Anything conforming to `AddressRepository` plugs into the facade, the SwiftUI
environment (`cambodiaAddress(_:)`), and the UIKit controller alike.

## See Also

- ``CambodiaAddress``
- ``AddressConfiguration``
- <doc:GettingStarted>
