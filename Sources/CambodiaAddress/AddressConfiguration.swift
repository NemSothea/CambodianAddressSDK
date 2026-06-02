import Foundation
import CambodiaAddressCore

/// Configuration for assembling a ``CambodiaAddress`` instance.
public struct AddressConfiguration: Sendable {

    /// Where address data is loaded from.
    public enum DataSource: Sendable {
        /// The dataset bundled with the SDK (default, offline-first).
        case bundled
        /// A caller-supplied in-memory dataset.
        case inMemory(AddressDataset)
        /// A remote endpoint (v3 — currently throws `notImplemented` on load).
        case remote(URL)
    }

    /// Language for place names and UI chrome.
    public var language: AddressLanguage
    /// Source of the dataset.
    public var dataSource: DataSource
    /// Default maximum number of search results.
    public var searchLimit: Int

    public init(
        language: AddressLanguage = .system,
        dataSource: DataSource = .bundled,
        searchLimit: Int = 25
    ) {
        self.language = language
        self.dataSource = dataSource
        self.searchLimit = searchLimit
    }
}
