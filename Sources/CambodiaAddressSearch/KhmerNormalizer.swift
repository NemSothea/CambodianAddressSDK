import Foundation

/// Normalizes and tokenizes Khmer/English text for indexing and querying.
///
/// This is the hardest correctness surface in the search module, so it lives in one place
/// with its own tests. Khmer combining marks are preserved; only Latin-range characters are
/// case-folded and diacritic-folded, so Khmer text is never corrupted.
public enum KhmerNormalizer {

    /// Zero-width / invisible characters frequently present in Khmer input.
    /// Khmer often uses ZWSP (U+200B) as a word boundary; we drop these for matching.
    private static let zeroWidth: Set<Unicode.Scalar> = [
        "\u{200B}", // zero-width space
        "\u{200C}", // zero-width non-joiner
        "\u{200D}", // zero-width joiner
        "\u{FEFF}", // zero-width no-break space / BOM
    ]

    /// Characters at or below this scalar value are treated as Latin and get diacritic/case
    /// folding. The Khmer block starts at U+1780, far above this, so it is untouched.
    private static let latinFoldingCeiling: UInt32 = 0x0250

    /// Upper bound on query length (in characters). Inputs longer than this are truncated
    /// before any processing — prevents unbounded work on adversarial multi-MB inputs.
    static let maxQueryLength = 500

    /// Produce a canonical form for comparison: NFC, zero-width stripped, lowercased,
    /// Latin diacritics folded, whitespace collapsed and trimmed.
    public static func normalize(_ input: String) -> String {
        // Guard against multi-MB adversarial inputs.
        let input = input.count > maxQueryLength ? String(input.prefix(maxQueryLength)) : input
        // 1. Canonical composition (NFC).
        let composed = input.precomposedStringWithCanonicalMapping

        // 2. Drop zero-width characters; normalize non-breaking space to a regular space.
        var scalars = String.UnicodeScalarView()
        for scalar in composed.unicodeScalars {
            if zeroWidth.contains(scalar) { continue }
            scalars.append(scalar == "\u{00A0}" ? " " : scalar)
        }
        // 3. Lowercase (no-op for Khmer), then fold Latin diacritics only.
        let lowered = String(scalars).lowercased()
        let folded = foldLatinDiacritics(lowered)

        // 4. Collapse runs of whitespace and trim.
        return folded
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Split normalized text into tokens on whitespace and punctuation.
    ///
    /// English names ("Phnom Penh") split into words; Khmer names (no inter-word spaces)
    /// typically yield a single token, which prefix/fuzzy matching then handles.
    public static func tokens(_ input: String) -> [String] {
        normalize(input)
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func foldLatinDiacritics(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for character in string {
            if character.unicodeScalars.allSatisfy({ $0.value < latinFoldingCeiling }) {
                result += String(character).folding(options: .diacriticInsensitive, locale: nil)
            } else {
                result.append(character)
            }
        }
        return result
    }
}
