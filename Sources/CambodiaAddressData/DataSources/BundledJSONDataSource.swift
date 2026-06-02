import Foundation
import CambodiaAddressCore

/// Loads the dataset from a JSON resource bundled with the package.
///
/// This is the default, offline-first source. It reads `cambodia_address.json` from the
/// module bundle and decodes the wire format into domain models.
public struct BundledJSONDataSource: AddressDataSource {
    private let resourceName: String
    private let bundle: Bundle

    /// - Parameter resourceName: JSON file name without extension. Defaults to `"cambodia_address"`.
    public init(resourceName: String = "cambodia_address") {
        self.init(resourceName: resourceName, bundle: .module)
    }

    /// Internal initializer allowing a custom bundle (used by tests).
    init(resourceName: String, bundle: Bundle) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    public func load() async throws -> AddressDataset {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw AddressError.resourceNotFound("\(resourceName).json")
        }
        do {
            let data = try Data(contentsOf: url)
            let wire = try JSONDecoder().decode(WireDataset.self, from: data)
            return wire.toDomain()
        } catch let error as AddressError {
            throw error
        } catch {
            throw AddressError.decodingFailed(String(describing: error))
        }
    }

    public var version: DatasetVersion {
        get async throws { try await load().version }
    }
}
