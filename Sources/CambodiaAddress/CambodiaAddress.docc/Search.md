# Searching addresses

Fast offline search across all four administrative levels, in Khmer or English.

## Overview

The search engine is built once from the dataset and runs entirely on device:
exact, prefix, and typo-tolerant fuzzy matching over both Khmer and English
names. Queries are normalized (Unicode NFC, zero-width space stripping,
diacritic folding) so raw user input just works.

### Basic search

```swift
let cambodia = CambodiaAddress.live()

// Khmer or English — same call.
let khmer   = try await cambodia.search("ដូនពេញ")
let english = try await cambodia.search("Doun Penh")

// Typo-tolerant: still finds "Kampong Cham".
let fuzzy   = try await cambodia.search("Kampong Chm")
```

Results are ranked exact > prefix > fuzzy, then by level
(province > district > commune > village).

### Restricting levels and limits

Search only certain levels of the hierarchy, and cap the result count:

```swift
// Province picker: only provinces, at most 5.
let provinces = try await cambodia.search("kam", levels: [.province], limit: 5)
```

When `limit` is omitted, the facade applies
``AddressConfiguration/searchLimit`` (default 25).

### Anatomy of a result

Each ``AddressSearchResult`` carries everything needed to render a row and
apply the match in one tap:

```swift
for result in try await cambodia.search("Doun Penh") {
    result.id     // NCDD code of the matched unit
    result.level  // .district
    result.name   // LocalizedName — km: "ដូនពេញ", en: "Doun Penh"
    result.path   // full AddressSelection breadcrumb down to the match
    result.score  // relevance, higher is better
}
```

`path` is the key field: it is a complete ``AddressSelection`` from province
down to the matched unit, so selecting a search result is just:

```swift
address = result.path
```

### Rendering a breadcrumb

Format the path with ``AddressFormatter`` — `provinceFirst` order reads
naturally as a breadcrumb:

```swift
let breadcrumb = AddressFormatter(language: .english, order: .provinceFirst)
    .string(from: result.path)
// "Phnom Penh, Doun Penh"
```

### Live search in SwiftUI

Debounce keystrokes with a cancellable `Task`:

```swift
@State private var query = ""
@State private var results: [AddressSearchResult] = []
@State private var searchTask: Task<Void, Never>?

func runSearch(_ q: String) {
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        results = (try? await cambodia.search(q)) ?? []
    }
}
```

> Note: ``CambodiaAddressPicker`` already does all of this internally — reach
> for the raw search API when building custom search UI.

## See Also

- ``AddressSearchResult``
- ``AddressSearchEngine``
- ``AddressFormatter``
