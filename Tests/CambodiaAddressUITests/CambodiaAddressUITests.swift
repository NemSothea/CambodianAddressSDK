import Testing
import Foundation
import CambodiaAddressCore
@testable import CambodiaAddressUI

@MainActor
@Suite struct AddressPickerViewModelTests {

    private func makeModel(_ repo: FakeAddressRepository = FakeAddressRepository(), language: AddressLanguage = .english) -> AddressPickerViewModel {
        AddressPickerViewModel(repository: repo, language: language, debounce: .milliseconds(20))
    }

    // MARK: Loading

    @Test func loadFetchesProvinces() async {
        let model = makeModel()
        await model.load()
        #expect(model.provinces.count == 2)
        #expect(model.errorMessage == nil)
    }

    @Test func loadRehydratesChildListsForSeededSelection() async {
        let repo = FakeAddressRepository()
        let model = AddressPickerViewModel(
            repository: repo,
            language: .english,
            initialSelection: repo.fullSelection
        )
        await model.load()
        #expect(model.districts.map(\.code) == ["1201"])
        #expect(model.communes.map(\.code) == ["120101"])
        #expect(model.villages.map(\.code) == ["12010101"])
    }

    // MARK: Cascading selection

    @Test func selectingProvinceLoadsDistrictsAndResetsDownstream() async {
        let model = makeModel()
        await model.load()
        await model.selectProvince(FakeAddressRepository.phnomPenh)
        #expect(model.selection.province?.code == "12")
        #expect(model.districts.map(\.code) == ["1201"])
        #expect(model.communes.isEmpty)
        #expect(model.villages.isEmpty)
    }

    @Test func changingProvinceClearsDeeperSelections() async {
        let model = makeModel()
        await model.load()
        await model.selectProvince(FakeAddressRepository.phnomPenh)
        await model.selectDistrict(FakeAddressRepository.dounPenh)
        await model.selectCommune(FakeAddressRepository.voatPhnum)
        model.selectVillage(FakeAddressRepository.village)
        #expect(model.isComplete)

        // Re-selecting a province must wipe district/commune/village.
        await model.selectProvince(FakeAddressRepository.kandal)
        #expect(model.selection.district == nil)
        #expect(model.selection.commune == nil)
        #expect(model.selection.village == nil)
        #expect(!model.isComplete)
    }

    @Test func enablementFollowsParentSelection() async {
        let model = makeModel()
        await model.load()
        #expect(model.isEnabled(.province))
        #expect(!model.isEnabled(.district))
        await model.selectProvince(FakeAddressRepository.phnomPenh)
        #expect(model.isEnabled(.district))
        #expect(!model.isEnabled(.commune))
    }

    @Test func selectByLevelAndIDResolvesModel() async {
        let model = makeModel()
        await model.load()
        await model.select(level: .province, id: "12")
        #expect(model.selection.province?.code == "12")
        await model.select(level: .district, id: "1201")
        #expect(model.selection.district?.code == "1201")
    }

    @Test func clearResetsEverything() async {
        let model = makeModel()
        await model.load()
        await model.selectProvince(FakeAddressRepository.phnomPenh)
        model.clear()
        #expect(model.selection.isEmpty)
        #expect(model.districts.isEmpty)
        #expect(!model.provinces.isEmpty) // province list stays loaded
    }

    // MARK: Search

    @Test func emptyQueryClearsResultsWithoutSearching() async {
        let repo = FakeAddressRepository()
        let model = makeModel(repo)
        model.search("   ")
        #expect(model.searchResults.isEmpty)
        #expect(repo.searchCount == 0)
    }

    @Test func debounceCoalescesRapidQueries() async {
        let repo = FakeAddressRepository()
        let model = makeModel(repo)

        model.search("p")
        model.search("ph")
        model.search("phn")
        await model.searchTask?.value

        #expect(repo.searchCount == 1)             // only the final query ran
        #expect(repo.lastSearchQuery == "phn")
        #expect(model.searchResults.count == 1)
    }

    @Test func applyingResultAdoptsPathAndReloadsChildren() async {
        let repo = FakeAddressRepository()
        let model = makeModel(repo)
        let result = try! await repo.search("x", levels: [.village], limit: 1).first!

        await model.apply(result)
        #expect(model.selection.isComplete)
        #expect(model.searchResults.isEmpty)
        #expect(model.searchQuery.isEmpty)
        #expect(model.districts.map(\.code) == ["1201"])   // child lists rehydrated
        #expect(model.communes.map(\.code) == ["120101"])
    }

    // MARK: Errors

    @Test func loadFailureSurfacesErrorMessage() async {
        let repo = FakeAddressRepository()
        repo.error = .decodingFailed("boom")
        let model = makeModel(repo)
        await model.load()
        #expect(model.errorMessage != nil)
        #expect(model.provinces.isEmpty)
    }

    // MARK: Formatting

    @Test func formattedAddressReflectsSelection() async {
        let model = makeModel()
        await model.load()
        await model.selectProvince(FakeAddressRepository.phnomPenh)
        await model.selectDistrict(FakeAddressRepository.dounPenh)
        #expect(model.formattedAddress == "Doun Penh, Phnom Penh")
    }
}
