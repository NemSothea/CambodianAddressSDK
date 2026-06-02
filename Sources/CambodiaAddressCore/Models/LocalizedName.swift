/// A place name carried in both Khmer and English.
///
/// Names are *data*, not UI strings, so they live inside every administrative model
/// rather than in a string catalog. Use ``resolved(for:)`` to pick a language.
public struct LocalizedName: Codable, Sendable, Hashable {
    /// Khmer spelling, e.g. `"ភ្នំពេញ"`.
    public let km: String
    /// English (romanized) spelling, e.g. `"Phnom Penh"`.
    public let en: String

    public init(km: String, en: String) {
        self.km = km
        self.en = en
    }

    /// The name in the requested language. `.system` resolves via the current locale.
    public func resolved(for language: AddressLanguage) -> String {
        switch language.resolved {
        case .khmer:   return km
        case .english: return en
        case .system:  return en // unreachable: `resolved` never yields `.system`
        }
    }
}
