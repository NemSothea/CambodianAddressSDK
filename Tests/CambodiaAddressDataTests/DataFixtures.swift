import Foundation
import CambodiaAddressCore
@testable import CambodiaAddressData

enum DataFixtures {
    /// A deterministic two-province dataset for repository logic tests.
    static let dataset = AddressDataset(
        version: "test-1.0",
        provinces: [
            Province(code: "12", name: LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh")),
            Province(code: "08", name: LocalizedName(km: "កណ្ដាល", en: "Kandal")),
        ],
        districts: [
            District(code: "1201", provinceCode: "12", name: LocalizedName(km: "ដូនពេញ", en: "Doun Penh"), type: .khan),
            District(code: "1202", provinceCode: "12", name: LocalizedName(km: "ចំការមន", en: "Chamkar Mon"), type: .khan),
            District(code: "0801", provinceCode: "08", name: LocalizedName(km: "កណ្ដាលស្ទឹង", en: "Kandal Stueng"), type: .district),
        ],
        communes: [
            Commune(code: "120101", districtCode: "1201", name: LocalizedName(km: "វត្តភ្នំ", en: "Voat Phnum"), type: .sangkat),
            Commune(code: "120103", districtCode: "1201", name: LocalizedName(km: "ផ្សារថ្មីទី៣", en: "Phsar Thmei Ti Bei"), type: .sangkat),
            Commune(code: "080101", districtCode: "0801", name: LocalizedName(km: "អំពៅព្រៃ", en: "Ampov Prey"), type: .commune),
        ],
        villages: [
            Village(code: "12010101", communeCode: "120101", name: LocalizedName(km: "ភូមិ១", en: "Phum 1")),
            Village(code: "12010102", communeCode: "120101", name: LocalizedName(km: "ភូមិ២", en: "Phum 2")),
            Village(code: "08010101", communeCode: "080101", name: LocalizedName(km: "ភូមិអំពៅព្រៃ", en: "Phum Ampov Prey")),
        ]
    )

    static func repository() -> DefaultAddressRepository {
        DefaultAddressRepository(dataSource: InMemoryDataSource(dataset))
    }
}

/// Data source that records how many times `load()` ran, to prove lazy single-load.
final class CountingDataSource: AddressDataSource, @unchecked Sendable {
    private let lock = NSLock()
    private var _loadCount = 0
    private let dataset: AddressDataset

    init(_ dataset: AddressDataset) { self.dataset = dataset }

    var loadCount: Int { lock.withLock { _loadCount } }

    func load() async throws -> AddressDataset {
        lock.withLock { _loadCount += 1 }
        return dataset
    }

    var version: DatasetVersion {
        get async throws { dataset.version }
    }
}
