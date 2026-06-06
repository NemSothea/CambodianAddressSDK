import Foundation

/// A Cambodian 5-digit postal code.
///
/// Cambodia Post adopted a 5-digit postal code system in 2016. The first two
/// digits match the province's NCDD code (zero-padded). The remaining three
/// digits identify the district or locality within the province.
///
/// ## Derivation
/// ```swift
/// let code = PostalCode(province: province, district: district)
/// print(code?.rawValue)  // e.g. "12000" for central Phnom Penh
/// ```
///
/// ## Static lookup
/// When the province and district are available as model values, use the
/// ``AddressSelection`` convenience:
/// ```swift
/// selection.postalCode?.rawValue  // "02000"
/// ```
public struct PostalCode: Codable, Sendable, Hashable, RawRepresentable {

    /// The 5-character postal code string, e.g. `"12000"`.
    public let rawValue: String

    /// Create a ``PostalCode`` directly from a validated string.
    ///
    /// Returns `nil` if `rawValue` is not exactly 5 ASCII digits.
    public init?(rawValue: String) {
        guard rawValue.count == 5, rawValue.allSatisfy(\.isNumber) else { return nil }
        self.rawValue = rawValue
    }

    /// Derive the postal code from a province + district.
    ///
    /// Formula: province code (2 digits) + district suffix (last 2 digits
    /// of the 4-digit district code) + `"0"`. E.g. province `"12"`, district
    /// `"1201"` → `"12010"`.  If the province or district code is malformed,
    /// returns `nil`.
    public init?(province: Province, district: District) {
        guard province.code.count == 2, province.code.allSatisfy(\.isNumber),
              district.code.count == 4, district.code.allSatisfy(\.isNumber) else {
            return nil
        }
        let districtSuffix = String(district.code.suffix(2))
        self.rawValue = province.code + districtSuffix + "0"
    }

    /// Province-only postal code (district suffix `"000"`).
    ///
    /// Useful when only the province is known.
    public init?(province: Province) {
        guard province.code.count == 2, province.code.allSatisfy(\.isNumber) else { return nil }
        self.rawValue = province.code + "000"
    }
}

extension PostalCode: CustomStringConvertible {
    public var description: String { rawValue }
}

// MARK: - AddressSelection convenience

extension AddressSelection {
    /// The most precise postal code derivable from the current selection.
    ///
    /// Returns a district-level code when both province and district are set,
    /// a province-level code when only the province is set, and `nil` when no
    /// province is selected.
    public var postalCode: PostalCode? {
        if let province, let district {
            return PostalCode(province: province, district: district)
        }
        if let province {
            return PostalCode(province: province)
        }
        return nil
    }
}
