import Testing
import Foundation
@testable import CambodiaAddress

// End-to-end integration tests through the fully-wired facade. Unlike the per-module tests,
// these exercise datasource → store → search engine → repository together.

@Suite struct CambodiaAddressFacadeTests {

    // MARK: Bundled (default)

    @Test func liveLoadsBundledProvinces() async throws {
        let cambodia = CambodiaAddress.live()
        let provinces = try await cambodia.provinces()
        #expect(!provinces.isEmpty)
        #expect(provinces.contains { $0.name.en == "Phnom Penh" })
    }

    @Test func drillsDownThroughAllLevels() async throws {
        let cambodia = CambodiaAddress.live()
        let provinces = try await cambodia.provinces()
        let province = try #require(provinces.first { $0.name.en == "Phnom Penh" })

        let districts = try await cambodia.districts(inProvince: province.code)
        let district = try #require(districts.first)

        let communes = try await cambodia.communes(inDistrict: district.code)
        let commune = try #require(communes.first)

        let villages = try await cambodia.villages(inCommune: commune.code)
        #expect(!villages.isEmpty)

        // Every child links back to its parent.
        #expect(district.provinceCode == province.code)
        #expect(commune.districtCode == district.code)
        #expect(villages.allSatisfy { $0.communeCode == commune.code })
    }

    // MARK: Search wired end-to-end (this is the first time search runs through the engine)

    @Test func searchFindsBundledPlaceByEnglish() async throws {
        let cambodia = CambodiaAddress.live()
        let results = try await cambodia.search("phnom")
        #expect(!results.isEmpty)
        #expect(results.contains { $0.name.en.localizedCaseInsensitiveContains("phnom") })
    }

    @Test func searchFindsBundledPlaceByKhmer() async throws {
        let cambodia = CambodiaAddress.live()
        let results = try await cambodia.search("ភ្នំពេញ")
        #expect(results.contains { $0.id == "12" })
    }

    @Test func searchRespectsConfiguredLimit() async throws {
        let cambodia = CambodiaAddress.live(.init(searchLimit: 2))
        let results = try await cambodia.search("phum") // appears in several villages
        #expect(results.count <= 2)
    }

    // MARK: Resolution & formatting

    @Test func resolvesSelectionFromVillageCode() async throws {
        let cambodia = CambodiaAddress.live()
        let selection = try await cambodia.selection(forVillageCode: "12010101")
        #expect(selection.isComplete)
        #expect(selection.isConsistent)
        #expect(selection.province?.code == "12")
    }

    @Test func formatUsesConfiguredLanguage() async throws {
        let cambodia = CambodiaAddress.live(.init(language: .english))
        let selection = try await cambodia.selection(forVillageCode: "12010101")
        let line = cambodia.format(selection)
        #expect(line.contains("Phnom Penh"))
        #expect(line.contains(", "))
    }

    // MARK: In-memory configuration

    @Test func inMemoryConfigurationLoadsCustomData() async throws {
        let dataset = AddressDataset(
            version: "custom",
            provinces: [Province(code: "99", name: LocalizedName(km: "សាកល្បង", en: "Testville"))],
            districts: [], communes: [], villages: []
        )
        let cambodia = CambodiaAddress.live(.init(dataSource: .inMemory(dataset)))
        let provinces = try await cambodia.provinces()
        #expect(provinces.map(\.code) == ["99"])
        #expect(try await cambodia.search("testville").contains { $0.id == "99" })
    }

    // MARK: Re-exports

    @Test func umbrellaReexportsPublicTypes() {
        // These types come from Core/Data/Search/UI — visible via the single umbrella import.
        let selection = AddressSelection(province: Province(code: "01", name: LocalizedName(km: "ក", en: "A")))
        #expect(selection.deepestLevel == .province)
        _ = AddressFormatter()                       // Core
        _ = InMemoryDataSource(.empty)               // Data
        _ = AddressSearchEngine(dataset: .empty)     // Search
    }
}
