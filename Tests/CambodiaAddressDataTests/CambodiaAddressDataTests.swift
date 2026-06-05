import Testing
import Foundation
import CambodiaAddressCore
@testable import CambodiaAddressData

// MARK: - Bundled JSON

@Suite struct BundledJSONDataSourceTests {
    @Test func decodesBundledDataset() async throws {
        // The bundled file is the full NCDD dataset (sourced via pumi). Assert sane lower
        // bounds rather than exact counts, so a dataset refresh doesn't break the test.
        let dataset = try await BundledJSONDataSource().load()
        #expect(dataset.provinces.count >= 24)      // Cambodia has 25 provinces incl. the capital
        #expect(dataset.districts.count >= 190)
        #expect(dataset.communes.count >= 1500)
        #expect(dataset.villages.count >= 13_000)
        #expect(!dataset.version.rawValue.isEmpty)
        #expect(dataset.provinces.contains { $0.name.en == "Phnom Penh" && $0.code == "12" })
    }

    @Test func bundledLinkageIsConsistent() async throws {
        // Every child's parent code must exist at the level above it.
        let dataset = try await BundledJSONDataSource().load()
        let provinceCodes = Set(dataset.provinces.map(\.code))
        let districtCodes = Set(dataset.districts.map(\.code))
        let communeCodes = Set(dataset.communes.map(\.code))

        #expect(dataset.districts.allSatisfy { provinceCodes.contains($0.provinceCode) })
        #expect(dataset.communes.allSatisfy { districtCodes.contains($0.districtCode) })
        #expect(dataset.villages.allSatisfy { communeCodes.contains($0.communeCode) })
    }

    @Test func missingResourceThrows() async {
        let source = BundledJSONDataSource(resourceName: "does_not_exist", bundle: .module)
        await #expect(throws: AddressError.self) {
            try await source.load()
        }
    }

    @Test func rejectsTooLargePayload() async {
        // A 100-byte cap is well below the real bundled file (~1.3 MB); load must throw.
        let source = BundledJSONDataSource(resourceName: "cambodia_address", bundle: .module, maximumFileBytes: 100)
        await #expect(throws: AddressError.payloadTooLarge) {
            try await source.load()
        }
    }

    @Test func versionDecodesWithoutFullLoad() async throws {
        // version should return a non-empty string using the lightweight decode path.
        let version = try await BundledJSONDataSource().version
        #expect(!version.rawValue.isEmpty)
    }
}

// MARK: - Wire DTO mapping

@Suite struct WireMappingTests {
    @Test func defaultsTypeWhenAbsent() throws {
        let json = """
        {
          "version": "1",
          "provinces": [{ "code": "12", "km": "ភ", "en": "P" }],
          "districts": [{ "code": "1201", "p": "12", "km": "ដ", "en": "D" }],
          "communes": [{ "code": "120101", "d": "1201", "km": "វ", "en": "V" }],
          "villages": [{ "code": "12010101", "c": "120101", "km": "ភ", "en": "Ph" }]
        }
        """
        let wire = try JSONDecoder().decode(WireDataset.self, from: Data(json.utf8))
        let domain = wire.toDomain()
        #expect(domain.districts.first?.type == .district)  // default
        #expect(domain.communes.first?.type == .commune)    // default
    }

    @Test func mapsExplicitTypes() throws {
        let domain = DataFixtures.dataset
        #expect(domain.districts.first(where: { $0.code == "1201" })?.type == .khan)
        #expect(domain.communes.first(where: { $0.code == "120101" })?.type == .sangkat)
    }
}

// MARK: - Repository linkage

@Suite struct RepositoryTests {
    let repo = DataFixtures.repository()

    @Test func provincesAreSortedByCode() async throws {
        let provinces = try await repo.provinces()
        #expect(provinces.map(\.code) == ["08", "12"])
    }

    @Test func districtsScopedToProvince() async throws {
        let districts = try await repo.districts(inProvince: "12")
        #expect(districts.map(\.code) == ["1201", "1202"])
        #expect(try await repo.districts(inProvince: "08").map(\.code) == ["0801"])
    }

    @Test func communesScopedToDistrict() async throws {
        let communes = try await repo.communes(inDistrict: "1201")
        #expect(communes.map(\.code) == ["120101", "120103"])
    }

    @Test func villagesScopedToCommune() async throws {
        let villages = try await repo.villages(inCommune: "120101")
        #expect(villages.map(\.code) == ["12010101", "12010102"])
    }

    @Test func unknownParentReturnsEmpty() async throws {
        #expect(try await repo.districts(inProvince: "99").isEmpty)
        #expect(try await repo.villages(inCommune: "999999").isEmpty)
    }

    @Test func selectionResolvesFullChain() async throws {
        let selection = try await repo.selection(forVillageCode: "12010102")
        #expect(selection.province?.code == "12")
        #expect(selection.district?.code == "1201")
        #expect(selection.commune?.code == "120101")
        #expect(selection.village?.code == "12010102")
        #expect(selection.isComplete)
        #expect(selection.isConsistent)
    }

    @Test func unknownVillageThrowsNotFound() async {
        await #expect(throws: AddressError.notFound(code: "00000000")) {
            try await DataFixtures.repository().selection(forVillageCode: "00000000")
        }
    }

    @Test func searchThrowsUntilEngineWired() async {
        await #expect(throws: AddressError.notImplemented) {
            try await DataFixtures.repository().search("phnom", limit: 5)
        }
    }
}

// MARK: - Lazy single-load

@Suite struct AddressStoreLoadingTests {
    @Test func datasetLoadsExactlyOnceAcrossManyQueries() async throws {
        let counter = CountingDataSource(DataFixtures.dataset)
        let repo = DefaultAddressRepository(dataSource: counter)

        _ = try await repo.provinces()
        _ = try await repo.districts(inProvince: "12")
        _ = try await repo.communes(inDistrict: "1201")
        _ = try await repo.selection(forVillageCode: "12010101")

        #expect(counter.loadCount == 1)
    }

    @Test func concurrentFirstQueriesStillLoadOnce() async throws {
        let counter = CountingDataSource(DataFixtures.dataset)
        let repo = DefaultAddressRepository(dataSource: counter)

        await withThrowingTaskGroup(of: [Province].self) { group in
            for _ in 0..<20 {
                group.addTask { try await repo.provinces() }
            }
            // Drain; ignore individual results.
            try? await group.waitForAll()
        }

        #expect(counter.loadCount == 1)
    }
}
