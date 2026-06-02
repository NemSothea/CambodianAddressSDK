/// Renders an ``AddressSelection`` as a single human-readable string.
///
/// Cambodian addresses are conventionally written most-specific first
/// (Village, Commune, District, Province), which is the default order.
public struct AddressFormatter: Sendable {

    /// Ordering of the components in the output string.
    public enum Order: Sendable {
        /// Village → Commune → District → Province (Cambodian convention, default).
        case villageFirst
        /// Province → District → Commune → Village.
        case provinceFirst
    }

    public var language: AddressLanguage
    public var order: Order
    public var separator: String

    public init(
        language: AddressLanguage = .system,
        order: Order = .villageFirst,
        separator: String = ", "
    ) {
        self.language = language
        self.order = order
        self.separator = separator
    }

    /// Format a selection. Empty levels are skipped; an empty selection yields `""`.
    /// - Parameter languageOverride: temporarily render in a different language without mutating the formatter.
    public func string(from selection: AddressSelection, language languageOverride: AddressLanguage? = nil) -> String {
        let lang = languageOverride ?? language

        // Build village → province, then reverse if requested.
        var parts: [String] = []
        if let village  = selection.village  { parts.append(village.name.resolved(for: lang)) }
        if let commune  = selection.commune  { parts.append(commune.name.resolved(for: lang)) }
        if let district = selection.district { parts.append(district.name.resolved(for: lang)) }
        if let province = selection.province { parts.append(province.name.resolved(for: lang)) }

        if order == .provinceFirst { parts.reverse() }
        return parts.joined(separator: separator)
    }
}
