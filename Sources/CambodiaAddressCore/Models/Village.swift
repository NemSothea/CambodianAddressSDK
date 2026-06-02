/// A village (ភូមិ) — the fourth and most granular administrative level.
///
/// Identity is the 8-digit NCDD ``code``; ``communeCode`` links it to its parent.
public struct Village: Codable, Sendable, Identifiable, Hashable {
    /// 8-digit NCDD code, e.g. `"12010101"`.
    public let code: String
    /// Parent commune code, e.g. `"120101"`.
    public let communeCode: String
    public let name: LocalizedName

    public var id: String { code }

    public init(code: String, communeCode: String, name: LocalizedName) {
        self.code = code
        self.communeCode = communeCode
        self.name = name
    }
}
