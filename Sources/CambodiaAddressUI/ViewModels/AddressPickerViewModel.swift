import Foundation
import Observation
import CambodiaAddressCore

/// Drives the address picker: owns the selection, the per-level option lists, search, and
/// loading/error state. `@MainActor` (all UI state) and `@Observable` (SwiftUI observation).
///
/// Async results are committed only if no newer operation has superseded them: every
/// selection-mutating call bumps ``selectionGeneration`` and every search bumps
/// ``searchGeneration``, and an in-flight result is dropped once its captured generation is
/// stale. This makes rapid taps / keystrokes race-free (latest input wins) even when the
/// repository's awaited calls are slow or out of order.
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

    // MARK: Concurrency guards
    /// Bumped by every selection-mutating call; stale cascade loads check it before committing.
    private var selectionGeneration = 0
    /// Bumped by every search (and by clear/apply); stale search results check it before committing.
    private var searchGeneration = 0
    /// Number of operations currently running through `run`; `isLoading` is `count > 0`.
    private var activeOperations = 0

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
        selectionGeneration &+= 1
        let generation = selectionGeneration
        await run {
            let provinces = try await self.repository.provinces()
            guard generation == self.selectionGeneration else { return }
            self.provinces = provinces
            try await self.rehydrateChildren(generation: generation)
        }
    }

    /// Adopt a selection pushed in from outside (e.g. the bound `$selection` changing in the host),
    /// reloading the child lists to match. No-op if it already equals the current selection.
    public func setSelection(_ newSelection: AddressSelection) async {
        guard newSelection != selection else { return }
        selectionGeneration &+= 1
        searchGeneration &+= 1
        let generation = selectionGeneration
        selection = newSelection
        districts = []; communes = []; villages = []
        searchResults = []; searchQuery = ""
        await run { try await self.rehydrateChildren(generation: generation) }
    }

    // MARK: - Selection (cascading)

    public func selectProvince(_ province: Province?) async {
        selectionGeneration &+= 1
        let generation = selectionGeneration
        selection.select(province: province)
        districts = []; communes = []; villages = []
        guard let province else { return }
        await run {
            let result = try await self.repository.districts(inProvince: province.code)
            guard generation == self.selectionGeneration else { return }
            self.districts = result
        }
    }

    public func selectDistrict(_ district: District?) async {
        selectionGeneration &+= 1
        let generation = selectionGeneration
        selection.select(district: district)
        communes = []; villages = []
        guard let district else { return }
        await run {
            let result = try await self.repository.communes(inDistrict: district.code)
            guard generation == self.selectionGeneration else { return }
            self.communes = result
        }
    }

    public func selectCommune(_ commune: Commune?) async {
        selectionGeneration &+= 1
        let generation = selectionGeneration
        selection.select(commune: commune)
        villages = []
        guard let commune else { return }
        await run {
            let result = try await self.repository.villages(inCommune: commune.code)
            guard generation == self.selectionGeneration else { return }
            self.villages = result
        }
    }

    public func selectVillage(_ village: Village?) {
        selectionGeneration &+= 1
        selection.select(village: village)
    }

    /// Clear the entire selection (keeps the loaded province list).
    public func clear() {
        selectionGeneration &+= 1
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
            searchGeneration &+= 1   // discard any in-flight result that would arrive after clearing
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
        searchGeneration &+= 1
        let generation = searchGeneration
        await run {
            let results = try await self.repository.search(query, limit: self.searchLimit)
            guard generation == self.searchGeneration else { return }
            self.searchResults = results
        }
    }

    /// Apply a search result, adopting its full path and reloading child lists for drill-down.
    public func apply(_ result: AddressSearchResult) async {
        searchTask?.cancel()
        selectionGeneration &+= 1
        searchGeneration &+= 1
        let generation = selectionGeneration
        searchResults = []
        searchQuery = ""
        selection = result.path
        await run { try await self.rehydrateChildren(generation: generation) }
    }

    // MARK: - Helpers

    /// Reload district/commune/village lists to match the current `selection`, bailing if a
    /// newer selection operation (matching `generation`) has superseded this one.
    private func rehydrateChildren(generation: Int) async throws {
        if let province = selection.province {
            let result = try await repository.districts(inProvince: province.code)
            guard generation == selectionGeneration else { return }
            districts = result
        }
        if let district = selection.district {
            let result = try await repository.communes(inDistrict: district.code)
            guard generation == selectionGeneration else { return }
            communes = result
        }
        if let commune = selection.commune {
            let result = try await repository.villages(inCommune: commune.code)
            guard generation == selectionGeneration else { return }
            villages = result
        }
    }

    private func run(_ operation: @MainActor () async throws -> Void) async {
        activeOperations += 1
        isLoading = true
        errorMessage = nil
        defer {
            activeOperations -= 1
            if activeOperations == 0 { isLoading = false }
        }
        do {
            try await operation()
        } catch {
            errorMessage = (error as? AddressError)?.errorDescription ?? error.localizedDescription
        }
    }
}
