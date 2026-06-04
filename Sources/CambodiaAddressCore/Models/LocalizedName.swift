/// A place name carried in Khmer and English, plus any number of additional locales.
///
/// Names are *data*, not UI strings, so they live inside every administrative model rather than
/// in a string catalog. `km` and `en` are the guaranteed baseline (the bundled dataset always
/// provides both); ``additional`` holds extra locales a custom dataset may supply. Use
/// ``resolved(for:)`` to pick a language with graceful fallback.
public struct LocalizedName: Codable, Sendable, Hashable {
    /// Khmer spelling, e.g. `"ភ្នំពេញ"`.
    public let km: String
    /// English (romanized) spelling, e.g. `"Phnom Penh"`.
    public let en: String
    /// Extra locales beyond km/en, keyed by lowercased BCP-47 code (e.g. `["fr": "Phnom Penh"]`).
    public let additional: [String: String]

    public init(km: String, en: String, additional: [String: String] = [:]) {
        self.km = km
        self.en = en
        self.additional = Dictionary(additional.map { ($0.key.lowercased(), $0.value) },
                                     uniquingKeysWith: { _, last in last })
    }

    /// The stored name for an exact locale code, or `nil` if absent/empty.
    public func value(forCode code: String) -> String? {
        switch code.lowercased() {
        case "km": return km.isEmpty ? nil : km
        case "en": return en.isEmpty ? nil : en
        case let other:
            guard let value = additional[other], !value.isEmpty else { return nil }
            return value
        }
    }

    /// The name in the requested language, following the language's fallback chain
    /// (e.g. `fr → en → km`). `.system` resolves via the current locale.
    public func resolved(for language: AddressLanguage) -> String {
        for code in language.resolutionOrder {
            if let value = value(forCode: code) { return value }
        }
        // Ultimate baseline: prefer English, then Khmer, even if the chain missed (empty fields).
        return en.isEmpty ? km : en
    }

    // MARK: Codable — `additional` is optional on the wire so older snapshots still decode.

    private enum CodingKeys: String, CodingKey { case km, en, additional }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let km = try container.decode(String.self, forKey: .km)
        let en = try container.decode(String.self, forKey: .en)
        let extra = try container.decodeIfPresent([String: String].self, forKey: .additional) ?? [:]
        self.init(km: km, en: en, additional: extra)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(km, forKey: .km)
        try container.encode(en, forKey: .en)
        if !additional.isEmpty { try container.encode(additional, forKey: .additional) }
    }
}
