/// Kind of third-level division.
public enum CommuneType: String, Codable, Sendable, CaseIterable {
    /// Commune (ឃុំ) — rural.
    case commune
    /// Sangkat (សង្កាត់) — urban.
    case sangkat
}

/// A commune / sangkat — the third administrative level.
///
/// Identity is the 6-digit NCDD ``code``; ``districtCode`` links it to its parent.
public struct Commune: Codable, Sendable, Identifiable, Hashable {
    /// 6-digit NCDD code, e.g. `"120101"`.
    public let code: String
    /// Parent district code, e.g. `"1201"`.
    public let districtCode: String
    public let name: LocalizedName
    public let type: CommuneType

    public var id: String { code }

    public init(code: String, districtCode: String, name: LocalizedName, type: CommuneType) {
        self.code = code
        self.districtCode = districtCode
        self.name = name
        self.type = type
    }
}
