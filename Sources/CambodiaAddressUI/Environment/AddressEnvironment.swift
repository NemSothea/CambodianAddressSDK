import SwiftUI
import CambodiaAddressCore
import CambodiaAddressData
import CambodiaAddressSearch

/// Builds the default repository used when a host hasn't injected one: bundled offline data
/// wired to the real search engine. UI can do this composition because it depends on both
/// Data and Search (the umbrella facade in Phase 5 exposes the same wiring publicly).
enum DefaultAddressEnvironment {
    static func makeRepository() -> any AddressRepository {
        DefaultAddressRepository(
            dataSource: BundledJSONDataSource(),
            searchProvider: { dataset in AddressSearchEngine(dataset: dataset) }
        )
    }
}

private struct AddressRepositoryKey: EnvironmentKey {
    static let defaultValue: any AddressRepository = DefaultAddressEnvironment.makeRepository()
}

private struct AddressLanguageKey: EnvironmentKey {
    static let defaultValue: AddressLanguage = .system
}

public extension EnvironmentValues {
    /// The repository the address picker reads from. Defaults to bundled offline data + search.
    var addressRepository: any AddressRepository {
        get { self[AddressRepositoryKey.self] }
        set { self[AddressRepositoryKey.self] = newValue }
    }

    /// The language used for place names and UI chrome. Defaults to `.system`.
    var addressLanguage: AddressLanguage {
        get { self[AddressLanguageKey.self] }
        set { self[AddressLanguageKey.self] = newValue }
    }
}

public extension View {
    /// Inject a custom ``AddressRepository`` for the address picker subtree.
    func cambodiaAddress(_ repository: any AddressRepository) -> some View {
        environment(\.addressRepository, repository)
    }

    /// Set the language for place names and UI chrome in the address picker subtree.
    func addressLanguage(_ language: AddressLanguage) -> some View {
        environment(\.addressLanguage, language)
    }
}
