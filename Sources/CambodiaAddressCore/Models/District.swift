/// Kind of second-level division. Cambodia uses different terms by context.
public enum DistrictType: String, Codable, Sendable, CaseIterable {
    /// District (ស្រុក) — rural.
    case district
    /// Municipality (ក្រុង).
    case municipality
    /// Khan (ខណ្ឌ) — urban district within a capital/municipality.
    case khan
}

/// A district / municipality / khan — the second administrative level.
///
/// Identity is the 4-digit NCDD ``code``; ``provinceCode`` links it to its parent.
public struct District: Codable, Sendable, Identifiable, Hashable {
    /// 4-digit NCDD code, e.g. `"1201"`.
    public let code: String
    /// Parent province code, e.g. `"12"`.
    public let provinceCode: String
    public let name: LocalizedName
    public let type: DistrictType

    public var id: String { code }

    public init(code: String, provinceCode: String, name: LocalizedName, type: DistrictType) {
        self.code = code
        self.provinceCode = provinceCode
        self.name = name
        self.type = type
    }
}
