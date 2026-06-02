import CambodiaAddressCore

/// Default ``AddressRepository`` backed by an ``AddressDataSource`` and an ``AddressStore`` cache.
///
/// A value type wrapping the actor cache, so it is trivially `Sendable` and cheap to pass
/// around / inject into view models. All concurrency safety lives in ``AddressStore``.
public struct DefaultAddressRepository: AddressRepository {
    private let store: AddressStore

    /// Create a repository whose search throws `notImplemented` until a real engine is wired
    /// in (Phase 5). Suitable for headless lookup (Milestone M1).
    /// - Parameter dataSource: where the dataset comes from (bundle, in-memory, remote).
    public init(dataSource: any AddressDataSource) {
        self.store = AddressStore(dataSource: dataSource, searchProvider: { _ in UnavailableSearchEngine() })
    }

    /// Create a repository with a custom search engine built from the loaded dataset.
    /// - Parameters:
    ///   - dataSource: where the dataset comes from (bundle, in-memory, remote).
    ///   - searchProvider: builds the search engine once the dataset has loaded.
    public init(
        dataSource: any AddressDataSource,
        searchProvider: @escaping @Sendable (AddressDataset) -> any AddressSearching
    ) {
        self.store = AddressStore(dataSource: dataSource, searchProvider: searchProvider)
    }

    public func provinces() async throws -> [Province] {
        try await store.provinces()
    }

    public func districts(inProvince provinceCode: String) async throws -> [District] {
        try await store.districts(inProvince: provinceCode)
    }

    public func communes(inDistrict districtCode: String) async throws -> [Commune] {
        try await store.communes(inDistrict: districtCode)
    }

    public func villages(inCommune communeCode: String) async throws -> [Village] {
        try await store.villages(inCommune: communeCode)
    }

    public func selection(forVillageCode villageCode: String) async throws -> AddressSelection {
        try await store.selection(forVillageCode: villageCode)
    }

    public func search(_ query: String, levels: Set<AdministrativeLevel>, limit: Int) async throws -> [AddressSearchResult] {
        try await store.search(query, levels: levels, limit: limit)
    }
}
