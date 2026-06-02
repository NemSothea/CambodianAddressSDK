import Foundation
import Observation
import CambodiaAddressCore

/// Drives the address picker: owns the selection, the per-level option lists, search, and
/// loading/error state. `@MainActor` (all UI state) and `@Observable` (SwiftUI observation).
@MainActor
@Observable
public final class AddressPickerViewModel {

    // MARK: Inputs
    private let repository: any AddressRepository
    private let searchLimit: Int
    private let debounce: Duration
    public let language: AddressLanguage

    // MARK: Selection & options
    public private(set) var selection: AddressSelection
    public private(set) var provinces: [Province] = []
    public private(set) var districts: [District] = []
    public private(set) var communes: [Commune] = []
    public private(set) var villages: [Village] = []

    // MARK: Search
    public private(set) var searchQuery: String = ""
    public private(set) var searchResults: [AddressSearchResult] = []
    /// In-flight debounced search; exposed (internal) so tests can await it deterministically.
    private(set) var searchTask: Task<Void, Never>?

    // MARK: Status
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public init(
        repository: any AddressRepository,
        language: AddressLanguage = .system,
        initialSelection: AddressSelection = .init(),
        searchLimit: Int = 25,
        debounce: Duration = .milliseconds(250)
    ) {
        self.repository = repository
        self.language = language
        self.selection = initialSelection
        self.searchLimit = searchLimit
        self.debounce = debounce
    }

    var strings: PickerStrings { PickerStrings(language: language) }

    /// Formatted one-line address for the current selection.
    public var formattedAddress: String {
        AddressFormatter(language: language).string(from: selection)
    }

    /// Whether a full (down to village) address has been chosen.
    public var isComplete: Bool { selection.isComplete }

    // MARK: - Lifecycle

    /// Load provinces, and re-hydrate child lists for any pre-seeded selection.
    public func load() async {
        await run {
            self.provinces = try await self.repository.provinces()
            if let province = self.selection.province {
                self.districts = try await self.repository.districts(inProvince: province.code)
            }
            if let district = self.selection.district {
                self.communes = try await self.repository.communes(inDistrict: district.code)
            }
            if let commune = self.selection.commune {
                self.villages = try await self.repository.villages(inCommune: commune.code)
            }
        }
    }

    // MARK: - Selection (cascading)

    public func selectProvince(_ province: Province?) async {
        selection.select(province: province)
        districts = []; communes = []; villages = []
        guard let province else { return }
        await run { self.districts = try await self.repository.districts(inProvince: province.code) }
    }

    public func selectDistrict(_ district: District?) async {
        selection.select(district: district)
        communes = []; villages = []
        guard let district else { return }
        await run { self.communes = try await self.repository.communes(inDistrict: district.code) }
    }

    public func selectCommune(_ commune: Commune?) async {
        selection.select(commune: commune)
        villages = []
        guard let commune else { return }
        await run { self.villages = try await self.repository.villages(inCommune: commune.code) }
    }

    public func selectVillage(_ village: Village?) {
        selection.select(village: village)
    }

    /// Clear the entire selection (keeps the loaded province list).
    public func clear() {
        selection.clear()
        districts = []; communes = []; villages = []
    }

    // MARK: - View helpers

    func items(for level: AdministrativeLevel) -> [PickerRowItem] {
        switch level {
        case .province: provinces.map { PickerRowItem(id: $0.code, name: $0.name) }
        case .district: districts.map { PickerRowItem(id: $0.code, name: $0.name) }
        case .commune:  communes.map { PickerRowItem(id: $0.code, name: $0.name) }
        case .village:  villages.map { PickerRowItem(id: $0.code, name: $0.name) }
        }
    }

    func selectedID(for level: AdministrativeLevel) -> String? {
        switch level {
        case .province: selection.province?.code
        case .district: selection.district?.code
        case .commune:  selection.commune?.code
        case .village:  selection.village?.code
        }
    }

    /// Whether a level can be edited yet (its parent must be chosen first).
    func isEnabled(_ level: AdministrativeLevel) -> Bool {
        switch level {
        case .province: true
        case .district: selection.province != nil
        case .commune:  selection.district != nil
        case .village:  selection.commune != nil
        }
    }

    func select(level: AdministrativeLevel, id: String) async {
        switch level {
        case .province: await selectProvince(provinces.first { $0.code == id })
        case .district: await selectDistrict(districts.first { $0.code == id })
        case .commune:  await selectCommune(communes.first { $0.code == id })
        case .village:  selectVillage(villages.first { $0.code == id })
        }
    }

    // MARK: - Search

    /// Debounced search. Cancels any in-flight query; an empty query clears results immediately.
    public func search(_ query: String) {
        searchQuery = query
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchTask = nil
            return
        }

        let debounce = debounce
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self.performSearch(trimmed)
        }
    }

    /// Run a search immediately (no debounce). Used by the debounced task and by tests.
    func performSearch(_ query: String) async {
        await run {
            self.searchResults = try await self.repository.search(query, limit: self.searchLimit)
        }
    }

    /// Apply a search result, adopting its full path and reloading child lists for drill-down.
    public func apply(_ result: AddressSearchResult) async {
        searchTask?.cancel()
        searchResults = []
        searchQuery = ""
        selection = result.path
        await run {
            if let province = self.selection.province {
                self.districts = try await self.repository.districts(inProvince: province.code)
            }
            if let district = self.selection.district {
                self.communes = try await self.repository.communes(inDistrict: district.code)
            }
            if let commune = self.selection.commune {
                self.villages = try await self.repository.villages(inCommune: commune.code)
            }
        }
    }

    // MARK: - Helpers

    private func run(_ operation: @MainActor () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = (error as? AddressError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}
