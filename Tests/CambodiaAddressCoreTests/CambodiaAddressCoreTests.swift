import Testing
import Foundation
@testable import CambodiaAddressCore

// MARK: - LocalizedName

@Suite struct LocalizedNameTests {
    let name = LocalizedName(km: "ភ្នំពេញ", en: "Phnom Penh")

    @Test func resolvesKhmer() {
        #expect(name.resolved(for: .khmer) == "ភ្នំពេញ")
    }

    @Test func resolvesEnglish() {
        #expect(name.resolved(for: .english) == "Phnom Penh")
    }

    @Test func systemResolvesToConcreteLanguage() {
        // `.system` must always collapse to a concrete name, never empty.
        let resolved = name.resolved(for: .system)
        #expect(resolved == "ភ្នំពេញ" || resolved == "Phnom Penh")
    }

    @Test func systemLanguageNeverStaysSystem() {
        #expect(AddressLanguage.system.resolved != .system)
    }
}

// MARK: - AdministrativeLevel

@Suite struct AdministrativeLevelTests {
    @Test func codeLengthsFollowNCDD() {
        #expect(AdministrativeLevel.province.codeLength == 2)
        #expect(AdministrativeLevel.district.codeLength == 4)
        #expect(AdministrativeLevel.commune.codeLength == 6)
        #expect(AdministrativeLevel.village.codeLength == 8)
    }

    @Test func parentChainIsConsistent() {
        #expect(AdministrativeLevel.village.parent == .commune)
        #expect(AdministrativeLevel.commune.parent == .district)
        #expect(AdministrativeLevel.district.parent == .province)
        #expect(AdministrativeLevel.province.parent == nil)
    }

    @Test func childChainIsConsistent() {
        #expect(AdministrativeLevel.province.child == .district)
        #expect(AdministrativeLevel.village.child == nil)
    }

    @Test func orderingIsLargestToSmallest() {
        #expect(AdministrativeLevel.province < .district)
        #expect(AdministrativeLevel.district < .village)
        #expect(AdministrativeLevel.allCases.sorted() == [.province, .district, .commune, .village])
    }
}

// MARK: - AddressCode

@Suite struct AddressCodeTests {
    @Test func levelInferredFromLength() {
        #expect(AddressCode.level(of: "12") == .province)
        #expect(AddressCode.level(of: "1201") == .district)
        #expect(AddressCode.level(of: "120103") == .commune)
        #expect(AddressCode.level(of: "12010301") == .village)
        #expect(AddressCode.level(of: "1") == nil)
    }

    @Test func parentCodeDropsTwoDigits() {
        #expect(AddressCode.parentCode(of: "12010301") == "120103")
        #expect(AddressCode.parentCode(of: "120103") == "1201")
        #expect(AddressCode.parentCode(of: "1201") == "12")
        #expect(AddressCode.parentCode(of: "12") == nil) // province has no parent
    }

    @Test func validityChecksLengthAndDigits() {
        #expect(AddressCode.isValid("1201", at: .district))
        #expect(!AddressCode.isValid("12", at: .district))     // wrong length
        #expect(!AddressCode.isValid("12ab", at: .district))   // non-numeric
    }

    @Test func descendantDetection() {
        #expect(AddressCode.isDescendant("12010301", of: "12"))
        #expect(AddressCode.isDescendant("120103", of: "1201"))
        #expect(!AddressCode.isDescendant("1301", of: "12"))
        #expect(!AddressCode.isDescendant("12", of: "12"))     // not its own descendant
    }
}

// MARK: - Codable round-trips

@Suite struct CodableTests {
    @Test func provinceRoundTrips() throws {
        let data = try JSONEncoder().encode(Fixtures.phnomPenh)
        let decoded = try JSONDecoder().decode(Province.self, from: data)
        #expect(decoded == Fixtures.phnomPenh)
    }

    @Test func datasetRoundTrips() throws {
        let dataset = AddressDataset(
            version: "2026.01",
            provinces: [Fixtures.phnomPenh],
            districts: [Fixtures.dounPenh],
            communes: [Fixtures.phsarThmei3],
            villages: [Fixtures.village]
        )
        let data = try JSONEncoder().encode(dataset)
        let decoded = try JSONDecoder().decode(AddressDataset.self, from: data)
        #expect(decoded == dataset)
        #expect(decoded.count == 4)
    }

    @Test func idEqualsCodeAndIsNotEncoded() throws {
        // `id` is computed from `code`, so it must not appear in the encoded JSON.
        let json = try String(data: JSONEncoder().encode(Fixtures.phnomPenh), encoding: .utf8)
        #expect(Fixtures.phnomPenh.id == "12")
        #expect(json?.contains("\"id\"") == false)
    }
}

// MARK: - AddressFormatter

@Suite struct AddressFormatterTests {
    let selection = Fixtures.fullSelection

    @Test func villageFirstEnglish() {
        let formatter = AddressFormatter(language: .english, order: .villageFirst)
        #expect(formatter.string(from: selection) == "Village 1, Phsar Thmei 3, Doun Penh, Phnom Penh")
    }

    @Test func provinceFirstEnglish() {
        let formatter = AddressFormatter(language: .english, order: .provinceFirst)
        #expect(formatter.string(from: selection) == "Phnom Penh, Doun Penh, Phsar Thmei 3, Village 1")
    }

    @Test func khmerOutput() {
        let formatter = AddressFormatter(language: .khmer, order: .villageFirst)
        #expect(formatter.string(from: selection) == "ភូមិ១, ផ្សារថ្មីទី៣, ដូនពេញ, ភ្នំពេញ")
    }

    @Test func languageOverrideDoesNotMutate() {
        let formatter = AddressFormatter(language: .khmer)
        let english = formatter.string(from: selection, language: .english)
        #expect(english.contains("Phnom Penh"))
        #expect(formatter.language == .khmer)
    }

    @Test func partialSelectionSkipsEmptyLevels() {
        let formatter = AddressFormatter(language: .english)
        let partial = AddressSelection(province: Fixtures.phnomPenh, district: Fixtures.dounPenh)
        #expect(formatter.string(from: partial) == "Doun Penh, Phnom Penh")
    }

    @Test func emptySelectionYieldsEmptyString() {
        let formatter = AddressFormatter(language: .english)
        #expect(formatter.string(from: AddressSelection()).isEmpty)
    }
}

// MARK: - AddressSelection

@Suite struct AddressSelectionTests {
    @Test func deepestLevelTracksSelection() {
        var selection = AddressSelection()
        #expect(selection.deepestLevel == nil)
        #expect(selection.isEmpty)

        selection.select(province: Fixtures.phnomPenh)
        #expect(selection.deepestLevel == .province)
        #expect(!selection.isComplete)

        selection.select(district: Fixtures.dounPenh)
        selection.select(commune: Fixtures.phsarThmei3)
        selection.select(village: Fixtures.village)
        #expect(selection.deepestLevel == .village)
        #expect(selection.isComplete)
    }

    @Test func selectingProvinceClearsDownstream() {
        var selection = Fixtures.fullSelection
        selection.select(province: Fixtures.phnomPenh)
        #expect(selection.district == nil)
        #expect(selection.commune == nil)
        #expect(selection.village == nil)
    }

    @Test func selectingDistrictClearsCommuneAndVillage() {
        var selection = Fixtures.fullSelection
        selection.select(district: Fixtures.dounPenh)
        #expect(selection.commune == nil)
        #expect(selection.village == nil)
        #expect(selection.province == Fixtures.phnomPenh) // upstream untouched
    }

    @Test func consistencyDetectsMismatchedParents() {
        #expect(Fixtures.fullSelection.isConsistent)

        let orphanDistrict = District(
            code: "1301", provinceCode: "13",
            name: LocalizedName(km: "x", en: "x"), type: .district
        )
        let inconsistent = AddressSelection(province: Fixtures.phnomPenh, district: orphanDistrict)
        #expect(!inconsistent.isConsistent)
    }

    @Test func clearResetsEverything() {
        var selection = Fixtures.fullSelection
        selection.clear()
        #expect(selection.isEmpty)
        #expect(selection.deepestLevel == nil)
    }
}

// MARK: - AddressError

@Suite struct AddressErrorTests {
    @Test func errorsHaveDescriptions() {
        #expect(AddressError.notFound(code: "99").errorDescription?.contains("99") == true)
        #expect(AddressError.notLoaded.errorDescription != nil)
    }

    @Test func errorsAreEquatable() {
        #expect(AddressError.notFound(code: "12") == .notFound(code: "12"))
        #expect(AddressError.notFound(code: "12") != .notFound(code: "13"))
    }
}
