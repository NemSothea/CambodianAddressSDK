import CambodiaAddressCore

/// Default search provider used until the real engine (Phase 3) is injected.
/// Keeps the data layer dependency-free of the search module.
struct UnavailableSearchEngine: AddressSearching {
    func search(_ query: String, levels: Set<AdministrativeLevel>, limit: Int) async throws -> [AddressSearchResult] {
        throw AddressError.notImplemented
    }
}

/// Decoded-and-indexed in-memory cache of the dataset.
///
/// An `actor`, so concurrent reads from multiple view models are safe with no locking in
/// callers. The dataset loads exactly once (lazily, on first query); parent→children index
/// dictionaries and the search engine are built at that point.
actor AddressStore {
    private let dataSource: any AddressDataSource
    private let searchProvider: @Sendable (AddressDataset) -> any AddressSearching

    /// Cached after the first successful load.
    private var indexed: Indexed?
    /// In-flight load, shared by concurrent first-callers to avoid a reentrant double-load.
    private var loadTask: Task<Indexed, Error>?

    init(
        dataSource: any AddressDataSource,
        searchProvider: @escaping @Sendable (AddressDataset) -> any AddressSearching = { _ in UnavailableSearchEngine() }
    ) {
        self.dataSource = dataSource
        self.searchProvider = searchProvider
    }

    // MARK: - Queries

    func provinces() async throws -> [Province] {
        try await ensureLoaded().provinces
    }

    func districts(inProvince provinceCode: String) async throws -> [District] {
        try await ensureLoaded().districtsByProvince[provinceCode] ?? []
    }

    func communes(inDistrict districtCode: String) async throws -> [Commune] {
        try await ensureLoaded().communesByDistrict[districtCode] ?? []
    }

    func villages(inCommune communeCode: String) async throws -> [Village] {
        try await ensureLoaded().villagesByCommune[communeCode] ?? []
    }

    func selection(forVillageCode villageCode: String) async throws -> AddressSelection {
        let index = try await ensureLoaded()
        guard let village = index.villagesByCode[villageCode] else {
            throw AddressError.notFound(code: villageCode)
        }
        let commune = index.communesByCode[village.communeCode]
        let district = commune.flatMap { index.districtsByCode[$0.districtCode] }
        let province = district.flatMap { index.provincesByCode[$0.provinceCode] }
        return AddressSelection(province: province, district: district, commune: commune, village: village)
    }

    func search(_ query: String, levels: Set<AdministrativeLevel>, limit: Int) async throws -> [AddressSearchResult] {
        try await ensureLoaded().search.search(query, levels: levels, limit: limit)
    }

    // MARK: - Loading & indexing

    private func ensureLoaded() async throws -> Indexed {
        if let indexed { return indexed }
        // Reuse an in-flight load so concurrent first-callers don't each hit the data source.
        if let loadTask { return try await loadTask.value }

        let dataSource = self.dataSource
        let searchProvider = self.searchProvider
        let task = Task { () throws -> Indexed in
            let dataset = try await dataSource.load()
            return Indexed(dataset: dataset, search: searchProvider(dataset))
        }
        loadTask = task

        do {
            let index = try await task.value
            indexed = index
            loadTask = nil
            return index
        } catch {
            loadTask = nil // allow a retry after a failed load
            throw error
        }
    }

    /// Precomputed lookup tables built once per dataset load.
    private struct Indexed {
        let provinces: [Province]
        let districtsByProvince: [String: [District]]
        let communesByDistrict: [String: [Commune]]
        let villagesByCommune: [String: [Village]]
        let provincesByCode: [String: Province]
        let districtsByCode: [String: District]
        let communesByCode: [String: Commune]
        let villagesByCode: [String: Village]
        let search: any AddressSearching

        init(dataset: AddressDataset, search: any AddressSearching) {
            // Sorted by code → stable, administratively meaningful display order.
            self.provinces = dataset.provinces.sorted { $0.code < $1.code }
            self.districtsByProvince = Dictionary(grouping: dataset.districts.sorted { $0.code < $1.code }, by: \.provinceCode)
            self.communesByDistrict = Dictionary(grouping: dataset.communes.sorted { $0.code < $1.code }, by: \.districtCode)
            self.villagesByCommune = Dictionary(grouping: dataset.villages.sorted { $0.code < $1.code }, by: \.communeCode)
            self.provincesByCode = Dictionary(dataset.provinces.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
            self.districtsByCode = Dictionary(dataset.districts.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
            self.communesByCode = Dictionary(dataset.communes.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
            self.villagesByCode = Dictionary(dataset.villages.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
            self.search = search
        }
    }
}
