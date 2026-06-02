import CambodiaAddressCore

/// A data source backed by an in-memory ``AddressDataset``.
///
/// Used for tests, SwiftUI previews, and consumers who load/build their own data.
public struct InMemoryDataSource: AddressDataSource {
    private let dataset: AddressDataset

    public init(_ dataset: AddressDataset) {
        self.dataset = dataset
    }

    public func load() async throws -> AddressDataset { dataset }

    public var version: DatasetVersion {
        get async throws { dataset.version }
    }
}
