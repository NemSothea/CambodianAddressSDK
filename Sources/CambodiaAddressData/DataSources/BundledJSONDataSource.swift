import Foundation
import CambodiaAddressCore

/// Loads the dataset from a JSON resource bundled with the package.
///
/// This is the default, offline-first source. It reads `cambodia_address.json` from the
/// module bundle and decodes the wire format into domain models.
public struct BundledJSONDataSource: AddressDataSource {
    private let resourceName: String
    private let bundle: Bundle
    /// Maximum accepted file size in bytes. Rejects suspiciously large custom bundles
    /// before they reach the decoder (DoS guard; the real NCDD dataset is ~1.3 MB).
    private let maximumFileBytes: Int

    /// - Parameter resourceName: JSON file name without extension. Defaults to `"cambodia_address"`.
    public init(resourceName: String = "cambodia_address") {
        self.init(resourceName: resourceName, bundle: .module)
    }

    /// Internal initializer allowing a custom bundle and size cap (used by tests).
    init(resourceName: String, bundle: Bundle, maximumFileBytes: Int = 64 * 1024 * 1024) {
        self.resourceName = resourceName
        self.bundle = bundle
        self.maximumFileBytes = maximumFileBytes
    }

    public func load() async throws -> AddressDataset {
        try DatasetDecoding.decode(try readFile())
    }

    /// Returns the dataset version without allocating the full domain model — avoids a full
    /// re-decode when the only caller is a sync/invalidation check.
    public var version: DatasetVersion {
        get async throws { try DatasetDecoding.decodeVersion(try readFile()) }
    }

    // MARK: - Helpers

    /// Read and size-validate the bundled JSON file.
    private func readFile() throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw AddressError.resourceNotFound("\(resourceName).json")
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw AddressError.decodingFailed(String(describing: error))
        }
        // Authoritative size guard — checked on actual bytes read, not filesystem attributes
        // (which can return nil on sandboxed or virtual filesystems).
        guard data.count <= maximumFileBytes else { throw AddressError.payloadTooLarge }
        return data
    }
}
