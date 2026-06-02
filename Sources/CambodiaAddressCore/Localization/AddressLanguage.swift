import Foundation

/// The language used to display Cambodian place names.
///
/// Place names ship in both Khmer and English (see ``LocalizedName``); this type
/// chooses which to surface. `.system` follows the device locale at resolution time.
public enum AddressLanguage: String, Codable, Sendable, CaseIterable {
    case khmer
    case english
    /// Resolve against `Locale.current` when displayed.
    case system

    /// Collapses `.system` into a concrete `.khmer`/`.english` using the current locale.
    ///
    /// Khmer when the current language is `km`, English otherwise. Returns `self`
    /// unchanged for the non-system cases.
    public var resolved: AddressLanguage {
        switch self {
        case .khmer:   return .khmer
        case .english: return .english
        case .system:
            let code = Locale.current.language.languageCode?.identifier
            return code == "km" ? .khmer : .english
        }
    }
}
