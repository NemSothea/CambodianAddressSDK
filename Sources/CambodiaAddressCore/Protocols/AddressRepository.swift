/// The single abstraction the UI and facade depend on.
///
/// Speaks domain types and `async`; hides whether data came from a bundle, a cache,
/// or the network. The default implementation lives in the data layer.
public protocol AddressRepository: Sendable {

    /// All provinces, in display order.
    func provinces() async throws -> [Province]

    /// Districts within the given province code.
    func districts(inProvince provinceCode: String) async throws -> [District]

    /// Communes/sangkats within the given district code.
    func communes(inDistrict districtCode: String) async throws -> [Commune]

    /// Villages within the given commune code.
    func villages(inCommune communeCode: String) async throws -> [Village]

    /// Resolve a full selection (province → village) from a village code.
    /// Useful for restoring a saved address or deep-linking.
    /// - Throws: ``AddressError/notFound(code:)`` if the village code is unknown.
    func selection(forVillageCode villageCode: String) async throws -> AddressSelection

    /// Search across the requested levels.
    /// - Parameters:
    ///   - query: raw user input (Khmer or English).
    ///   - levels: which levels to include in results.
    ///   - limit: maximum number of results.
    func search(
        _ query: String,
        levels: Set<AdministrativeLevel>,
        limit: Int
    ) async throws -> [AddressSearchResult]
}

public extension AddressRepository {
    /// Search all levels with a default limit.
    func search(_ query: String, limit: Int = 25) async throws -> [AddressSearchResult] {
        try await search(query, levels: Set(AdministrativeLevel.allCases), limit: limit)
    }
}
