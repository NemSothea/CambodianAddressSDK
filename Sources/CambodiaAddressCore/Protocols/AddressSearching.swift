/// An offline search engine over the address dataset.
///
/// Declared in Core so the repository (Core's `AddressRepository`) can delegate search
/// without the data layer depending on the search module. The concrete engine is built
/// from a loaded ``AddressDataset`` and injected at composition time.
public protocol AddressSearching: Sendable {
    func search(
        _ query: String,
        levels: Set<AdministrativeLevel>,
        limit: Int
    ) async throws -> [AddressSearchResult]
}
