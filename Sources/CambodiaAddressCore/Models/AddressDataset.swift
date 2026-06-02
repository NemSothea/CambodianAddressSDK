/// Identifies a dataset revision, used to decide when a newer snapshot supersedes the bundled one (v3 sync).
public struct DatasetVersion: Codable, Sendable, Hashable, Comparable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }

    /// Lexicographic comparison — adequate for zero-padded `"YYYY.MM"` style versions.
    public static func < (lhs: DatasetVersion, rhs: DatasetVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A complete, decoded snapshot of the administrative hierarchy.
///
/// This is the domain-level value the rest of the SDK consumes. The on-disk/wire
/// representation is a separate concern owned by the data layer.
public struct AddressDataset: Codable, Sendable, Hashable {
    public let version: DatasetVersion
    public let provinces: [Province]
    public let districts: [District]
    public let communes: [Commune]
    public let villages: [Village]

    public init(
        version: DatasetVersion,
        provinces: [Province],
        districts: [District],
        communes: [Commune],
        villages: [Village]
    ) {
        self.version = version
        self.provinces = provinces
        self.districts = districts
        self.communes = communes
        self.villages = villages
    }

    /// An empty dataset (no units).
    public static let empty = AddressDataset(
        version: "0.0.0", provinces: [], districts: [], communes: [], villages: []
    )

    /// Total number of administrative units across all levels.
    public var count: Int {
        provinces.count + districts.count + communes.count + villages.count
    }
}
