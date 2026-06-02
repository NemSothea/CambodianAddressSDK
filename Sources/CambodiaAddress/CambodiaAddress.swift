import Foundation
import CambodiaAddressCore
import CambodiaAddressData
import CambodiaAddressSearch

/// The SDK's front door: a headless facade over a fully-wired ``AddressRepository``.
///
/// ```swift
/// let cambodia = CambodiaAddress.live()
/// let provinces = try await cambodia.provinces()
/// let results   = try await cambodia.search("ដូនពេញ")
/// let line      = cambodia.format(selection) // "Doun Penh, Phnom Penh"
/// ```
///
/// For UI, inject it into the SwiftUI environment with `.cambodiaAddress(cambodia)`.
public struct CambodiaAddress: Sendable {

    /// The underlying repository. Inject into views, or use the convenience passthroughs below.
    public let repository: any AddressRepository
    public let configuration: AddressConfiguration

    /// A formatter pre-set to the configured language.
    public var formatter: AddressFormatter {
        AddressFormatter(language: configuration.language)
    }

    /// Wrap an existing repository (advanced / testing).
    public init(repository: any AddressRepository, configuration: AddressConfiguration = .init()) {
        self.repository = repository
        self.configuration = configuration
    }

    /// Assemble the SDK: data source → store → search engine → repository. The composition root.
    public static func live(_ configuration: AddressConfiguration = .init()) -> CambodiaAddress {
        let repository = DefaultAddressRepository(
            dataSource: makeDataSource(configuration.dataSource),
            searchProvider: { dataset in AddressSearchEngine(dataset: dataset) }
        )
        return CambodiaAddress(repository: repository, configuration: configuration)
    }

    private static func makeDataSource(_ kind: AddressConfiguration.DataSource) -> any AddressDataSource {
        switch kind {
        case .bundled:               BundledJSONDataSource()
        case .inMemory(let dataset): InMemoryDataSource(dataset)
        case .remote(let url):       RemoteAddressDataSource(endpoint: url)
        }
    }

    // MARK: - Headless lookup (passthroughs)

    public func provinces() async throws -> [Province] {
        try await repository.provinces()
    }

    public func districts(inProvince provinceCode: String) async throws -> [District] {
        try await repository.districts(inProvince: provinceCode)
    }

    public func communes(inDistrict districtCode: String) async throws -> [Commune] {
        try await repository.communes(inDistrict: districtCode)
    }

    public func villages(inCommune communeCode: String) async throws -> [Village] {
        try await repository.villages(inCommune: communeCode)
    }

    public func selection(forVillageCode villageCode: String) async throws -> AddressSelection {
        try await repository.selection(forVillageCode: villageCode)
    }

    /// Search across all levels. Uses the configured `searchLimit` unless overridden.
    public func search(
        _ query: String,
        levels: Set<AdministrativeLevel> = Set(AdministrativeLevel.allCases),
        limit: Int? = nil
    ) async throws -> [AddressSearchResult] {
        try await repository.search(query, levels: levels, limit: limit ?? configuration.searchLimit)
    }

    /// Format a selection using the configured language.
    public func format(_ selection: AddressSelection) -> String {
        formatter.string(from: selection)
    }
}
