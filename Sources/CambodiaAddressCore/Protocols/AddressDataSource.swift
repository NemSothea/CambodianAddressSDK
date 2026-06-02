/// Supplies a complete ``AddressDataset`` snapshot to the repository.
///
/// Implementations know *where* data comes from (app bundle, in-memory fixture, remote API)
/// but nothing about querying, caching, or indexing — those belong to higher layers.
public protocol AddressDataSource: Sendable {
    /// Load and return the full dataset. May be expensive; callers cache the result.
    func load() async throws -> AddressDataset

    /// The version of the data this source would provide, for sync/invalidation decisions.
    var version: DatasetVersion { get async throws }
}
