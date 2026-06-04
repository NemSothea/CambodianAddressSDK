import Testing
import Foundation
@testable import CambodiaAddressCore

// MARK: - LocalizedName fallback resolution

@Suite struct MultiLocaleNameTests {
    let trilingual = LocalizedName(
        km: "ភ្នំពេញ", en: "Phnom Penh",
        additional: ["fr": "Phnom Penh", "ZH": "金边"]   // mixed-case key on purpose
    )

    @Test func resolvesAdditionalLocale() {
        #expect(trilingual.resolved(for: .locale("fr")) == "Phnom Penh")
    }

    @Test func additionalLocaleKeysAreCaseInsensitive() {
        #expect(trilingual.resolved(for: .locale("zh")) == "金边")   // stored as "ZH"
    }

    @Test func unknownLocaleFallsBackToEnglish() {
        let kmEnOnly = LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh")
        #expect(kmEnOnly.resolved(for: .locale("de")) == "Phnom Penh")   // de → en
    }

    @Test func fallsBackToKhmerWhenEnglishMissing() {
        let kmOnly = LocalizedName(km: "ភ្នំពេញ", en: "")
        #expect(kmOnly.resolved(for: .locale("de")) == "ភ្នំពេញ")   // de → en(empty) → km
    }

    @Test func valueForCodeReturnsNilWhenAbsent() {
        #expect(trilingual.value(forCode: "de") == nil)
        #expect(trilingual.value(forCode: "km") == "ភ្នំពេញ")
    }

    @Test func roundTripsAdditionalLocalesThroughCodable() throws {
        let data = try JSONEncoder().encode(trilingual)
        let back = try JSONDecoder().decode(LocalizedName.self, from: data)
        #expect(back == trilingual)
        #expect(back.resolved(for: .locale("zh")) == "金边")
    }

    @Test func decodesLegacyNameWithoutAdditionalKey() throws {
        let json = Data(#"{"km":"ភ្នំពេញ","en":"Phnom Penh"}"#.utf8)
        let name = try JSONDecoder().decode(LocalizedName.self, from: json)
        #expect(name.additional.isEmpty)
        #expect(name.en == "Phnom Penh")
    }
}

// MARK: - AddressLanguage

@Suite struct AddressLanguageTests {
    @Test func builtInsMapToLocaleCodes() {
        #expect(AddressLanguage.khmer.rawValue == "km")
        #expect(AddressLanguage.english.rawValue == "en")
    }

    @Test func legacyRawValuesNormalize() {
        #expect(AddressLanguage(rawValue: "khmer") == .khmer)
        #expect(AddressLanguage(rawValue: "english") == .english)
    }

    @Test func localeFactoryCreatesArbitraryCode() {
        #expect(AddressLanguage.locale("fr").rawValue == "fr")
        #expect(AddressLanguage("fr") == .locale("fr"))   // string-literal init
    }

    @Test func resolutionOrderFallsBackThroughEnglishAndKhmer() {
        #expect(AddressLanguage.locale("fr").resolutionOrder == ["fr", "en", "km"])
        #expect(AddressLanguage.khmer.resolutionOrder == ["km", "en"])
        #expect(AddressLanguage.english.resolutionOrder == ["en", "km"])
    }

    @Test func regionalCodeAddsBaseSubtag() {
        #expect(AddressLanguage.locale("zh-Hant").resolutionOrder == ["zh-hant", "zh", "en", "km"])
    }

    @Test func systemNeverStaysSystem() {
        #expect(AddressLanguage.system.resolved != .system)
    }

    @Test func allCasesAreTheBuiltIns() {
        #expect(AddressLanguage.allCases == [.khmer, .english, .system])
    }

    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(AddressLanguage.locale("fr"))
        #expect(try JSONDecoder().decode(AddressLanguage.self, from: data) == .locale("fr"))
    }

    @Test func legacyEncodedStringDecodes() throws {
        let data = Data(#""khmer""#.utf8)
        #expect(try JSONDecoder().decode(AddressLanguage.self, from: data) == .khmer)
    }
}

// MARK: - KhmerNumerals

@Suite struct KhmerNumeralsTests {
    @Test func convertsAsciiToKhmer() {
        #expect(KhmerNumerals.toKhmer("Village 1") == "Village ១")
        #expect(KhmerNumerals.toKhmer("120103") == "១២០១០៣")
    }

    @Test func convertsKhmerToLatin() {
        #expect(KhmerNumerals.toLatin("ភូមិ ៣") == "ភូមិ 3")
        #expect(KhmerNumerals.toLatin("១២៣") == "123")
    }

    @Test func leavesNonDigitsUntouched() {
        #expect(KhmerNumerals.toKhmer("Phnom Penh") == "Phnom Penh")
        #expect(KhmerNumerals.toKhmer("Village ៣") == "Village ៣")   // already Khmer
    }
}

// MARK: - AddressFormatter numerals

@Suite struct FormatterNumeralsTests {
    let selection = Fixtures.fullSelection

    @Test func khmerNumeralsConvertAsciiDigits() {
        let formatter = AddressFormatter(language: .english, order: .provinceFirst, numerals: .khmer)
        #expect(formatter.string(from: selection) == "Phnom Penh, Doun Penh, Phsar Thmei ៣, Village ១")
    }

    @Test func latinIsTheDefault() {
        let formatter = AddressFormatter(language: .english)   // numerals defaults to .latin
        #expect(formatter.string(from: selection).contains("Village 1"))
    }

    @Test func automaticKeepsLatinForEnglish() {
        let formatter = AddressFormatter(language: .english, numerals: .automatic)
        #expect(formatter.string(from: selection).contains("Village 1"))
    }

    @Test func automaticUsesKhmerForKhmerLanguage() {
        // Force English names but Khmer language with automatic numerals → digits become Khmer.
        let formatter = AddressFormatter(language: .english, numerals: .automatic)
        let khmerised = formatter.string(from: selection, language: .khmer)
        #expect(!khmerised.contains("1"))
    }
}
