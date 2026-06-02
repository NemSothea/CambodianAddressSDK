/// A user's in-progress or completed address selection — the SDK's primary output value.
///
/// Levels fill top-down. Selecting a level via the `select(...)` helpers clears every
/// level below it, keeping the selection internally consistent.
public struct AddressSelection: Codable, Sendable, Hashable {
    public var province: Province?
    public var district: District?
    public var commune: Commune?
    public var village: Village?

    public init(
        province: Province? = nil,
        district: District? = nil,
        commune: Commune? = nil,
        village: Village? = nil
    ) {
        self.province = province
        self.district = district
        self.commune = commune
        self.village = village
    }

    /// `true` once a village (the deepest level) is selected.
    public var isComplete: Bool { village != nil }

    /// `true` when nothing is selected.
    public var isEmpty: Bool { province == nil }

    /// The most granular level currently selected, or `nil` if empty.
    public var deepestLevel: AdministrativeLevel? {
        if village  != nil { return .village }
        if commune  != nil { return .commune }
        if district != nil { return .district }
        if province != nil { return .province }
        return nil
    }

    /// `true` when each selected level's parent code matches the level above it.
    public var isConsistent: Bool {
        if let district, let province, district.provinceCode != province.code { return false }
        if let commune, let district, commune.districtCode != district.code { return false }
        if let village, let commune, village.communeCode != commune.code { return false }
        return true
    }

    // MARK: - Cascading mutation

    /// Set the province and clear district, commune, and village.
    public mutating func select(province: Province?) {
        self.province = province
        district = nil
        commune = nil
        village = nil
    }

    /// Set the district and clear commune and village.
    public mutating func select(district: District?) {
        self.district = district
        commune = nil
        village = nil
    }

    /// Set the commune and clear village.
    public mutating func select(commune: Commune?) {
        self.commune = commune
        village = nil
    }

    /// Set the village.
    public mutating func select(village: Village?) {
        self.village = village
    }

    /// Reset to empty.
    public mutating func clear() {
        province = nil
        district = nil
        commune = nil
        village = nil
    }
}
