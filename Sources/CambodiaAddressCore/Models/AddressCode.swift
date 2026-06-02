/// Helpers for working with NCDD administrative codes.
///
/// Codes are zero-padded decimal strings whose length encodes the level
/// (province 2, district 4, commune 6, village 8), and where a child's code is
/// prefixed by its parent's code — so parentage is derivable from the code alone.
public enum AddressCode {

    /// The level implied by a code's length, or `nil` if it matches no level.
    public static func level(of code: String) -> AdministrativeLevel? {
        AdministrativeLevel.allCases.first { $0.codeLength == code.count }
    }

    /// The parent code (two digits shorter), or `nil` for a province / malformed code.
    public static func parentCode(of code: String) -> String? {
        guard code.count > AdministrativeLevel.province.codeLength,
              code.count.isMultiple(of: 2) else { return nil }
        return String(code.dropLast(2))
    }

    /// Whether `code` consists solely of ASCII digits.
    public static func isNumeric(_ code: String) -> Bool {
        !code.isEmpty && code.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Whether `code` is a well-formed code for the given level.
    public static func isValid(_ code: String, at level: AdministrativeLevel) -> Bool {
        code.count == level.codeLength && isNumeric(code)
    }

    /// Whether `childCode` is nested under `parentCode` (prefix relationship).
    public static func isDescendant(_ childCode: String, of parentCode: String) -> Bool {
        childCode.count > parentCode.count && childCode.hasPrefix(parentCode)
    }
}
