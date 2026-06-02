/// The four levels of Cambodia's administrative hierarchy, ordered from largest to smallest:
/// Province → District → Commune/Sangkat → Village.
public enum AdministrativeLevel: String, Codable, Sendable, CaseIterable, Comparable, Identifiable {
    case province
    case district
    case commune
    case village

    public var id: String { rawValue }

    /// Number of digits in an NCDD code at this level (province 2 … village 8).
    public var codeLength: Int {
        switch self {
        case .province: 2
        case .district: 4
        case .commune:  6
        case .village:  8
        }
    }

    /// Distance from the root (`province` == 0). Used for ordering.
    public var depth: Int {
        switch self {
        case .province: 0
        case .district: 1
        case .commune:  2
        case .village:  3
        }
    }

    /// The enclosing level, or `nil` for `province`.
    public var parent: AdministrativeLevel? {
        switch self {
        case .province: nil
        case .district: .province
        case .commune:  .district
        case .village:  .commune
        }
    }

    /// The contained level, or `nil` for `village`.
    public var child: AdministrativeLevel? {
        switch self {
        case .province: .district
        case .district: .commune
        case .commune:  .village
        case .village:  nil
        }
    }

    public static func < (lhs: AdministrativeLevel, rhs: AdministrativeLevel) -> Bool {
        lhs.depth < rhs.depth
    }
}
