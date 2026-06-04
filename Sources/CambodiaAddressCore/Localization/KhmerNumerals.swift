/// Converts between ASCII (`0`–`9`) and Khmer (`០`–`៩`) digits.
///
/// Cambodian addresses are often written with Khmer numerals (e.g. village "ភូមិ ៣" rather than
/// "ភូមិ 3"). ``AddressFormatter`` uses this when rendering in Khmer.
public enum KhmerNumerals {
    /// Khmer digit zero, `U+17E0`. Khmer `0…9` are contiguous at `U+17E0…U+17E9`.
    private static let khmerZero: UInt32 = 0x17E0

    /// Replace ASCII digits with Khmer digits, leaving everything else untouched.
    public static func toKhmer(_ string: String) -> String {
        String(string.map { character in
            guard let ascii = character.asciiValue, (0x30...0x39).contains(ascii) else { return character }
            let digit = UInt32(ascii - 0x30)
            return Character(UnicodeScalar(khmerZero + digit)!)
        })
    }

    /// Replace Khmer digits with ASCII digits, leaving everything else untouched.
    public static func toLatin(_ string: String) -> String {
        String(string.map { character in
            guard let scalar = character.unicodeScalars.first,
                  character.unicodeScalars.count == 1,
                  (khmerZero...(khmerZero + 9)).contains(scalar.value)
            else { return character }
            return Character(UnicodeScalar(0x30 + (scalar.value - khmerZero))!)
        })
    }
}
