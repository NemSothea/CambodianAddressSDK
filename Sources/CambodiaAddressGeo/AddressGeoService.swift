import Foundation
import CambodiaAddressCore

/// Combines a ``NearestCommuneFinder`` with an ``AddressRepository`` to resolve
/// a GPS coordinate into a full ``AddressSelection`` (commune → district → province).
///
/// ```swift
/// let service = AddressGeoService(repository: CambodiaAddress.live().repository)
/// let selection = try await service.selection(near: Coordinate(latitude: 11.56, longitude: 104.92))
/// // selection.commune?.name.en → "Voat Phnum"
/// ```
public struct AddressGeoService: Sendable {
    private let finder: NearestCommuneFinder
    private let repository: any AddressRepository

    /// - Parameters:
    ///   - finder: Centroid finder. Defaults to the bundled dataset.
    ///   - repository: Repository for resolving commune code → full selection.
    public init(
        finder: NearestCommuneFinder = NearestCommuneFinder(),
        repository: any AddressRepository
    ) {
        self.finder = finder
        self.repository = repository
    }

    /// Resolve a GPS coordinate to the nearest commune and walk its parent chain.
    ///
    /// - Parameter coordinate: The device's current location.
    /// - Returns: A partial ``AddressSelection`` with province, district, and commune
    ///   filled in. Village is `nil` — the user should confirm or refine it.
    /// - Throws: ``GeoError`` if the centroid data cannot be loaded,
    ///   or ``AddressError`` if the resolved commune code isn't in the dataset.
    public func selection(near coordinate: Coordinate) async throws -> AddressSelection {
        let communeCode = try await finder.nearestCommuneCode(to: coordinate)
        // selection(forVillageCode:) requires an 8-digit code; we have 6 digits.
        // Walk up via communes → district → province using the repository.
        let communes = try await repository.communes(inDistrict: String(communeCode.prefix(4)))
        guard let commune = communes.first(where: { $0.code == communeCode }) else {
            throw GeoError.decodingFailed("Commune \(communeCode) not found in repository")
        }
        let districts = try await repository.districts(inProvince: String(communeCode.prefix(2)))
        guard let district = districts.first(where: { $0.code == commune.districtCode }) else {
            throw GeoError.decodingFailed("District \(commune.districtCode) not found in repository")
        }
        let provinces = try await repository.provinces()
        guard let province = provinces.first(where: { $0.code == district.provinceCode }) else {
            throw GeoError.decodingFailed("Province \(district.provinceCode) not found in repository")
        }
        return AddressSelection(province: province, district: district, commune: commune)
    }

    /// Return just the nearest commune code without resolving the full selection.
    public func nearestCommuneCode(to coordinate: Coordinate) async throws -> String {
        try await finder.nearestCommuneCode(to: coordinate)
    }
}
