import Foundation
import CambodiaAddressCore

/// Fetches a newer dataset from a remote endpoint (v3 API sync).
///
/// Reserved seam: the offline-first design means the SDK never depends on this. It is the
/// single sanctioned stub in the codebase and throws ``AddressError/notImplemented`` until
/// v3 implements fetching, validation, and a persistent cache (see ARCHITECTURE.md roadmap).
public struct RemoteAddressDataSource: AddressDataSource {
    public let endpoint: URL

    public init(endpoint: URL) {
        self.endpoint = endpoint
    }

    public func load() async throws -> AddressDataset {
        throw AddressError.notImplemented
    }

    public var version: DatasetVersion {
        get async throws { throw AddressError.notImplemented }
    }
}
