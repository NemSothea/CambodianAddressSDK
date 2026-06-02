import Foundation
import CambodiaAddressCore

/// Hand-written, controllable repository for view-model tests. Records call counts and can be
/// told to fail, without any mocking framework.
final class FakeAddressRepository: AddressRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _searchCount = 0
    private var _lastSearchQuery: String?

    var searchCount: Int { lock.withLock { _searchCount } }
    var lastSearchQuery: String? { lock.withLock { _lastSearchQuery } }

    /// When non-nil, every method throws this.
    var error: AddressError?

    // Fixed two-province dataset.
    static let phnomPenh = Province(code: "12", name: LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh"))
    static let kandal = Province(code: "08", name: LocalizedName(km: "កណ្ដាល", en: "Kandal"))
    static let dounPenh = District(code: "1201", provinceCode: "12", name: LocalizedName(km: "ដូនពេញ", en: "Doun Penh"), type: .khan)
    static let voatPhnum = Commune(code: "120101", districtCode: "1201", name: LocalizedName(km: "វត្តភ្នំ", en: "Voat Phnum"), type: .sangkat)
    static let village = Village(code: "12010101", communeCode: "120101", name: LocalizedName(km: "ភូមិ១", en: "Phum 1"))

    func provinces() async throws -> [Province] {
        try throwIfNeeded()
        return [Self.phnomPenh, Self.kandal]
    }

    func districts(inProvince provinceCode: String) async throws -> [District] {
        try throwIfNeeded()
        return provinceCode == "12" ? [Self.dounPenh] : []
    }

    func communes(inDistrict districtCode: String) async throws -> [Commune] {
        try throwIfNeeded()
        return districtCode == "1201" ? [Self.voatPhnum] : []
    }

    func villages(inCommune communeCode: String) async throws -> [Village] {
        try throwIfNeeded()
        return communeCode == "120101" ? [Self.village] : []
    }

    func selection(forVillageCode villageCode: String) async throws -> AddressSelection {
        try throwIfNeeded()
        guard villageCode == Self.village.code else { throw AddressError.notFound(code: villageCode) }
        return fullSelection
    }

    func search(_ query: String, levels: Set<AdministrativeLevel>, limit: Int) async throws -> [AddressSearchResult] {
        lock.withLock { _searchCount += 1; _lastSearchQuery = query }
        try throwIfNeeded()
        return [
            AddressSearchResult(id: Self.village.code, level: .village, name: Self.village.name, path: fullSelection, score: 1.0)
        ]
    }

    var fullSelection: AddressSelection {
        AddressSelection(province: Self.phnomPenh, district: Self.dounPenh, commune: Self.voatPhnum, village: Self.village)
    }

    private func throwIfNeeded() throws {
        if let error { throw error }
    }
}
