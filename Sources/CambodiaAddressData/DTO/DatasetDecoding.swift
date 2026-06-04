import Foundation
import CambodiaAddressCore

/// Single decode path for raw dataset bytes, shared by every data source that reads the wire
/// format (bundle, remote). Treats input as untrusted and maps any failure to ``AddressError``.
enum DatasetDecoding {
    /// Decode wire-format JSON bytes into a domain ``AddressDataset``.
    static func decode(_ data: Data) throws -> AddressDataset {
        do {
            return try JSONDecoder().decode(WireDataset.self, from: data).toDomain()
        } catch {
            throw AddressError.decodingFailed(String(describing: error))
        }
    }
}
