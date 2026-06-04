import Foundation

/// The language used to display Cambodian place names.
///
/// Place names ship in Khmer and English (see ``LocalizedName``), and custom datasets may carry
/// additional locales. This type chooses which to surface, with a defined fallback chain so a
/// requested locale that a name lacks degrades gracefully (e.g. `fr → en → km`).
///
/// Modelled as an extensible value type (like ``DatasetVersion``): the built-ins ``khmer``,
/// ``english`` and ``system`` are static constants, and any BCP-47 code is valid via
/// ``locale(_:)``. `.system` follows the device locale at resolution time.
public struct AddressLanguage: Sendable, Hashable, Codable, RawRepresentable,
                               ExpressibleByStringLiteral, CaseIterable, CustomStringConvertible {
    /// Canonical code: a BCP-47 language code (e.g. `"km"`, `"en"`, `"fr"`) or `"system"`.
    public let rawValue: String

    public init(rawValue: String) {
        // Normalise legacy/alias spellings to locale codes so old persisted values still decode.
        switch rawValue.lowercased() {
        case "khmer":   self.rawValue = "km"
        case "english": self.rawValue = "en"
        case "system":  self.rawValue = "system"
        default:        self.rawValue = rawValue
        }
    }

    public init(stringLiteral value: String) { self.init(rawValue: value) }

    public var description: String { rawValue }

    // MARK: Built-ins

    /// Khmer place names.
    public static let khmer = AddressLanguage(rawValue: "km")
    /// English (romanized) place names.
    public static let english = AddressLanguage(rawValue: "en")
    /// Follow the device locale (`Locale.current`) at display time.
    public static let system = AddressLanguage(rawValue: "system")

    /// An arbitrary BCP-47 language code, e.g. `.locale("fr")` or `.locale("zh-Hant")`.
    public static func locale(_ code: String) -> AddressLanguage { AddressLanguage(rawValue: code) }

    /// The built-in, user-pickable languages. Custom locales remain valid via ``locale(_:)``.
    public static let allCases: [AddressLanguage] = [.khmer, .english, .system]

    // MARK: Resolution

    /// Collapses ``system`` into the device's language; returns `self` unchanged otherwise.
    public var resolved: AddressLanguage {
        guard rawValue == "system" else { return self }
        let code = Locale.current.language.languageCode?.identifier
        return AddressLanguage(rawValue: code ?? "en")
    }

    /// The primary locale code to look up first (`"km"`, `"en"`, `"fr"`, …), device-resolved for `.system`.
    public var primaryCode: String {
        rawValue == "system" ? resolved.primaryCode : rawValue.lowercased()
    }

    /// Ordered locale codes to try when resolving a name: the primary code, its base language
    /// subtag (e.g. `"zh-hant" → "zh"`), then the `en`/`km` baseline that every name carries.
    public var resolutionOrder: [String] {
        let primary = primaryCode
        var order = [primary]
        if let dash = primary.firstIndex(of: "-") {
            let base = String(primary[..<dash])
            if !order.contains(base) { order.append(base) }
        }
        for fallback in ["en", "km"] where !order.contains(fallback) {
            order.append(fallback)
        }
        return order
    }

    // MARK: Codable (single string value, compatible with the former enum representation)

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.init(rawValue: raw)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
