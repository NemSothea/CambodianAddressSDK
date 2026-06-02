/// A Cambodian province or capital (e.g. Phnom Penh).
///
/// Identity is the 2-digit NCDD ``code`` — stable across dataset updates.
public struct Province: Codable, Sendable, Identifiable, Hashable {
    /// 2-digit NCDD code, e.g. `"12"` (Phnom Penh).
    public let code: String
    /// Bilingual name.
    public let name: LocalizedName

    public var id: String { code }

    public init(code: String, name: LocalizedName) {
        self.code = code
        self.name = name
    }
}
