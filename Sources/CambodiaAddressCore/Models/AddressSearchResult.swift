/// A single match returned by the search engine, with its full breadcrumb path.
///
/// Lives in Core (not Search) because ``AddressRepository`` returns it — the search
/// module produces these, but the domain owns the type.
public struct AddressSearchResult: Sendable, Identifiable, Hashable {
    /// Code of the matched unit (== the deepest unit in ``path``).
    public let id: String
    /// Which level matched.
    public let level: AdministrativeLevel
    /// The matched unit's name.
    public let name: LocalizedName
    /// Full selection from province down to the matched unit, for one-tap apply.
    public let path: AddressSelection
    /// Relevance score; higher is better. Used for ranking.
    public let score: Double

    public init(
        id: String,
        level: AdministrativeLevel,
        name: LocalizedName,
        path: AddressSelection,
        score: Double
    ) {
        self.id = id
        self.level = level
        self.name = name
        self.path = path
        self.score = score
    }
}
